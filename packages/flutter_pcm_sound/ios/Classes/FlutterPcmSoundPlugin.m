#import "FlutterPcmSoundPlugin.h"
#import <AudioToolbox/AudioToolbox.h>

#if TARGET_OS_IOS
#import <AVFoundation/AVFoundation.h>
#endif

#define kOutputBus 0
#define kInputBus 1
#define NAMESPACE @"flutter_pcm_sound"

typedef NS_ENUM(NSUInteger, LogLevel) {
    none = 0,
    error = 1,
    standard = 2,
    verbose = 3,
};

@interface FlutterPcmSoundPlugin () <FlutterStreamHandler>
@property(nonatomic) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic) FlutterMethodChannel *mMethodChannel;
@property(nonatomic) FlutterEventChannel *mRecordingEventChannel;
@property(nonatomic) FlutterEventSink mRecordingEventSink;
@property(nonatomic) LogLevel mLogLevel;
@property(nonatomic) AudioComponentInstance mAudioUnit;
@property(nonatomic) NSMutableData *mSamples;
@property(nonatomic) int mNumChannels;
@property(nonatomic) int mFeedThreshold;
@property(nonatomic) NSUInteger mTotalFeeds;
@property(nonatomic) NSUInteger mLastLowBufferFeed;
@property(nonatomic) NSUInteger mLastZeroFeed;
@property(nonatomic) bool mDidSetup;
@property(nonatomic) BOOL mIsAppActive;
@property(nonatomic) BOOL mAllowBackgroundAudio;
@property(nonatomic) BOOL mIsRecording;
@property(nonatomic) int mInputSampleRate;
@property(nonatomic) int mInputNumChannels;
@end

@implementation FlutterPcmSoundPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar
{
    FlutterMethodChannel *methodChannel = [FlutterMethodChannel methodChannelWithName:NAMESPACE @"/methods"
                                                                    binaryMessenger:[registrar messenger]];
    FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:NAMESPACE @"/recording"
                                                                  binaryMessenger:[registrar messenger]];

    FlutterPcmSoundPlugin *instance = [[FlutterPcmSoundPlugin alloc] init];
    instance.mMethodChannel = methodChannel;
    instance.mRecordingEventChannel = eventChannel;
    instance.mRecordingEventSink = nil;
    instance.mLogLevel = verbose;
    instance.mSamples = [NSMutableData new];
    instance.mFeedThreshold = 8000;
    instance.mTotalFeeds = 0;
    instance.mLastLowBufferFeed = 0;
    instance.mLastZeroFeed = 0;
    instance.mDidSetup = false;
    instance.mIsAppActive = true;
    instance.mAllowBackgroundAudio = false;
    instance.mIsRecording = NO;
    instance.mInputSampleRate = 24000;
    instance.mInputNumChannels = 1;

#if TARGET_OS_IOS
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:instance selector:@selector(onWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:instance selector:@selector(onDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
#endif

    [eventChannel setStreamHandler:instance];
    [registrar addMethodCallDelegate:instance channel:methodChannel];
}

#if TARGET_OS_IOS
- (void)onWillResignActive:(NSNotification *)note {
  self.mIsAppActive = NO;
}

- (void)onDidBecomeActive:(NSNotification *)note {
  self.mIsAppActive = YES;
}
#endif

#pragma mark - FlutterStreamHandler

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.mRecordingEventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.mRecordingEventSink = nil;
    return nil;
}

#pragma mark - Method calls

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result
{
    @try
    {
        if ([@"setLogLevel" isEqualToString:call.method])
        {
            NSDictionary *args = (NSDictionary*)call.arguments;
            NSNumber *logLevelNumber  = args[@"log_level"];

            self.mLogLevel = (LogLevel)[logLevelNumber integerValue];

            result(@YES);
        }
        else if ([@"setup" isEqualToString:call.method])
        {
            NSDictionary *args = (NSDictionary*)call.arguments;
            NSNumber *sampleRate       = args[@"sample_rate"];
            NSNumber *numChannels      = args[@"num_channels"];
#if TARGET_OS_IOS
            NSString *iosAudioCategory = args[@"ios_audio_category"];
            self.mAllowBackgroundAudio = [args[@"ios_allow_background_audio"] boolValue];
#endif

            self.mNumChannels = [numChannels intValue];
            self.mInputSampleRate = [sampleRate intValue];
            self.mInputNumChannels = self.mNumChannels;

#if TARGET_OS_IOS
            // iOS audio category
            AVAudioSessionCategory category = AVAudioSessionCategorySoloAmbient;
            if ([iosAudioCategory isEqualToString:@"ambient"]) {
                category = AVAudioSessionCategoryAmbient;
            } else if ([iosAudioCategory isEqualToString:@"soloAmbient"]) {
                category = AVAudioSessionCategorySoloAmbient;
            } else if ([iosAudioCategory isEqualToString:@"playback"]) {
                category = AVAudioSessionCategoryPlayback;
            }
            else if ([iosAudioCategory isEqualToString:@"playAndRecord"]) {
                category = AVAudioSessionCategoryPlayAndRecord;
            }

            NSError *error = nil;
            [[AVAudioSession sharedInstance] setCategory:category error:&error];
            if (error) {
                NSLog(@"Error setting AVAudioSession category: %@", error);
                result([FlutterError errorWithCode:@"AVAudioSessionError"
                                        message:@"Error setting AVAudioSession category"
                                        details:[error localizedDescription]]);
                return;
            }

            [[AVAudioSession sharedInstance] setActive:YES error:&error];
            if (error) {
                NSLog(@"Error activating AVAudioSession: %@", error);
                result([FlutterError errorWithCode:@"AVAudioSessionError"
                                        message:@"Error activating AVAudioSession"
                                        details:[error localizedDescription]]);
                return;
            }
#endif

            // cleanup
            if (_mAudioUnit != nil) {
                [self cleanup];
            }

            // create
            AudioComponentDescription desc;
            desc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IOS
            desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
#else // MacOS
            desc.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
            desc.componentFlags = 0;
            desc.componentFlagsMask = 0;
            desc.componentManufacturer = kAudioUnitManufacturer_Apple;

            AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
            OSStatus status = AudioComponentInstanceNew(inputComponent, &_mAudioUnit);
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioComponentInstanceNew failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

            // stream format
            AudioStreamBasicDescription audioFormat;
            audioFormat.mSampleRate = [sampleRate intValue];
            audioFormat.mFormatID = kAudioFormatLinearPCM;
            audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            audioFormat.mFramesPerPacket = 1;
            audioFormat.mChannelsPerFrame = self.mNumChannels;
            audioFormat.mBitsPerChannel = 16;
            audioFormat.mBytesPerFrame = self.mNumChannels * (audioFormat.mBitsPerChannel / 8);
            audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;

            // output format
            status = AudioUnitSetProperty(_mAudioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    kOutputBus,
                                    &audioFormat,
                                    sizeof(audioFormat));
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioUnitSetProperty Output StreamFormat failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

            // output callback
            AURenderCallbackStruct callback;
            callback.inputProc = RenderCallback;
            callback.inputProcRefCon = (__bridge void *)(self);

            status = AudioUnitSetProperty(_mAudioUnit,
                                kAudioUnitProperty_SetRenderCallback,
                                kAudioUnitScope_Global,
                                kOutputBus,
                                &callback,
                                sizeof(callback));
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioUnitSetProperty SetRenderCallback failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

#if TARGET_OS_IOS
            // enable input
            UInt32 enableInput = 1;
            status = AudioUnitSetProperty(_mAudioUnit,
                                          kAudioOutputUnitProperty_EnableIO,
                                          kAudioUnitScope_Input,
                                          kInputBus,
                                          &enableInput,
                                          sizeof(enableInput));
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioUnitSetProperty EnableIO failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

            // input format
            status = AudioUnitSetProperty(_mAudioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          kInputBus,
                                          &audioFormat,
                                          sizeof(audioFormat));
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioUnitSetProperty Input StreamFormat failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

            // input callback
            AURenderCallbackStruct inputCallback;
            inputCallback.inputProc = InputCallback;
            inputCallback.inputProcRefCon = (__bridge void *)(self);

            status = AudioUnitSetProperty(_mAudioUnit,
                                          kAudioOutputUnitProperty_SetInputCallback,
                                          kAudioUnitScope_Global,
                                          kInputBus,
                                          &inputCallback,
                                          sizeof(inputCallback));
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioUnitSetProperty SetInputCallback failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }
#endif

            // initialize
            status = AudioUnitInitialize(_mAudioUnit);
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioUnitInitialize failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

#if TARGET_OS_IOS
            // ensure voice processing AEC/AGC is enabled
            UInt32 bypass = 0;
            AudioUnitSetProperty(_mAudioUnit, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, kInputBus, &bypass, sizeof(bypass));
            AudioUnitSetProperty(_mAudioUnit, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, kOutputBus, &bypass, sizeof(bypass));

            UInt32 agc = 1;
            AudioUnitSetProperty(_mAudioUnit, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, kInputBus, &agc, sizeof(agc));
#endif

            self.mDidSetup = true;

            result(@YES);
        }
        else if ([@"feed" isEqualToString:call.method])
        {
            if (self.mDidSetup == false) {
                result([FlutterError errorWithCode:@"Setup" message:@"must call setup first" details:nil]);
                return;
            }

            if (!self.mIsAppActive && !self.mAllowBackgroundAudio) {
                @synchronized (self.mSamples) {[self.mSamples setLength:0];}
                [self.mMethodChannel invokeMethod:@"OnFeedSamples" arguments:@{@"remaining_frames": @(0)}];
                result(@YES);
                return;
            }

            NSDictionary *args = (NSDictionary*)call.arguments;
            FlutterStandardTypedData *buffer = args[@"buffer"];

            @synchronized (self.mSamples) {
                [self.mSamples appendData:buffer.data];
                self.mTotalFeeds += 1;
            }

            OSStatus status = AudioOutputUnitStart(_mAudioUnit);
            if (status != noErr) {
                NSString* message = [NSString stringWithFormat:@"AudioOutputUnitStart failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

            result(@YES);
        }
        else if ([@"setPreferredSampleRate" isEqualToString:call.method])
        {
            NSDictionary *args = (NSDictionary*)call.arguments;
            NSNumber *sampleRate = args[@"sample_rate"];

            NSError *error = nil;
            [[AVAudioSession sharedInstance] setPreferredSampleRate:[sampleRate doubleValue] error:&error];
            if (error) {
                NSLog(@"Error setting preferred sample rate: %@", error);
                result([FlutterError errorWithCode:@"AVAudioSessionError"
                                        message:@"Error setting preferred sample rate"
                                        details:[error localizedDescription]]);
                return;
            }
            result(@YES);
        }
        else if ([@"setFeedThreshold" isEqualToString:call.method])
        {
            NSDictionary *args = (NSDictionary*)call.arguments;
            NSNumber *feedThreshold = args[@"feed_threshold"];

            @synchronized (self.mSamples) {
                self.mFeedThreshold = [feedThreshold intValue];
            }

            result(@YES);
        }
        else if ([@"startRecording" isEqualToString:call.method])
        {
            if (self.mDidSetup == false) {
                result([FlutterError errorWithCode:@"Setup" message:@"must call setup first" details:nil]);
                return;
            }

            self.mIsRecording = YES;
            OSStatus status = AudioOutputUnitStart(_mAudioUnit);
            if (status != noErr) {
                self.mIsRecording = NO;
                NSString* message = [NSString stringWithFormat:@"AudioOutputUnitStart failed. OSStatus: %@", @(status)];
                result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
                return;
            }

            result(@YES);
        }
        else if ([@"stopRecording" isEqualToString:call.method])
        {
            self.mIsRecording = NO;
            result(@YES);
        }
        else if([@"release" isEqualToString:call.method])
        {
            [self cleanup];
            result(@YES);
        }
        else
        {
            result([FlutterError errorWithCode:@"functionNotImplemented" message:call.method details:nil]);
        }
    }
    @catch (NSException *e)
    {
        NSString *stackTrace = [[e callStackSymbols] componentsJoinedByString:@"\n"];
        NSDictionary *details = @{@"stackTrace": stackTrace};
        result([FlutterError errorWithCode:@"iosException" message:[e reason] details:details]);
    }
}

- (void)cleanup
{
    if (_mAudioUnit != nil) {
        AudioOutputUnitStop(_mAudioUnit);
        AudioUnitUninitialize(_mAudioUnit);
        AudioComponentInstanceDispose(_mAudioUnit);
        _mAudioUnit = nil;
        self.mDidSetup = false;
    }
    @synchronized (self.mSamples) {
        [self.mSamples setLength:0];
    }
    self.mIsRecording = NO;
}

- (void)stopAudioUnit
{
    if (_mAudioUnit != nil) {
        UInt32 isRunning = 0;
        UInt32 size = sizeof(isRunning);
        OSStatus status = AudioUnitGetProperty(_mAudioUnit,
                                            kAudioOutputUnitProperty_IsRunning,
                                            kAudioUnitScope_Global,
                                            0,
                                            &isRunning,
                                            &size);
        if (status != noErr) {
            NSLog(@"AudioUnitGetProperty IsRunning failed. OSStatus: %@", @(status));
            return;
        }
        if (isRunning) {
            status = AudioOutputUnitStop(_mAudioUnit);
            if (status != noErr) {
                NSLog(@"AudioOutputUnitStop failed. OSStatus: %@", @(status));
            } else {
                NSLog(@"AudioUnit stopped because no more samples");
            }
        }
    }
}

#pragma mark - Callbacks

static OSStatus RenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    FlutterPcmSoundPlugin *instance = (__bridge FlutterPcmSoundPlugin *)(inRefCon);

    NSUInteger totalFeeds = 0;
    NSUInteger remainingFrames;
    NSUInteger feedThreshold = 0;

    @synchronized (instance.mSamples) {

        memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);

        NSUInteger bytesToCopy = MIN(ioData->mBuffers[0].mDataByteSize, [instance.mSamples length]);

        memcpy(ioData->mBuffers[0].mData, [instance.mSamples bytes], bytesToCopy);

        NSRange range = NSMakeRange(0, bytesToCopy);
        [instance.mSamples replaceBytesInRange:range withBytes:NULL length:0];

        remainingFrames = [instance.mSamples length] / (instance.mNumChannels * sizeof(short));
        totalFeeds = instance.mTotalFeeds;
        feedThreshold = (NSUInteger)instance.mFeedThreshold;
    }

    BOOL isLowBufferEvent = (remainingFrames <= feedThreshold) && (instance.mLastLowBufferFeed != totalFeeds);
    BOOL isZeroCrossingEvent = (remainingFrames == 0) && (instance.mLastZeroFeed != totalFeeds);

    if (remainingFrames == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized (instance.mSamples) {
                if ([instance.mSamples length] != 0) {return;}
            }
            [instance stopAudioUnit];
        });
    }

    if (isLowBufferEvent || isZeroCrossingEvent) {
        if(isLowBufferEvent) {instance.mLastLowBufferFeed = totalFeeds;}
        if(isZeroCrossingEvent) {instance.mLastZeroFeed = totalFeeds;}
        NSDictionary *response = @{@"remaining_frames": @(remainingFrames)};
        dispatch_async(dispatch_get_main_queue(), ^{
            [instance.mMethodChannel invokeMethod:@"OnFeedSamples" arguments:response];
        });
    }

    return noErr;
}

#if TARGET_OS_IOS
static OSStatus InputCallback(void *inRefCon,
                              AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
    FlutterPcmSoundPlugin *instance = (__bridge FlutterPcmSoundPlugin *)(inRefCon);

    if (!instance.mIsRecording || instance.mRecordingEventSink == nil || ioData == NULL) {
        return noErr;
    }

    AudioBuffer buffer = ioData->mBuffers[0];
    if (buffer.mData == NULL || buffer.mDataByteSize == 0) {
        return noErr;
    }

    NSData *data = [NSData dataWithBytes:buffer.mData length:buffer.mDataByteSize];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (instance.mIsRecording && instance.mRecordingEventSink) {
            // Standard codec will encode NSData as FlutterStandardTypedData/Uint8List.
            instance.mRecordingEventSink(data);
        }
    });

    return noErr;
}
#endif

@end
