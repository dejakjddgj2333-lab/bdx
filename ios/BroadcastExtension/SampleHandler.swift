//
//  SampleHandler.swift
//  BroadcastExtension
//
//  屏幕共享广播上传扩展（ReplayKit）。采集系统屏幕帧，通过 App Group
//  共享容器内的 Unix domain socket 传给主 App 进程，由 flutter_webrtc/LiveKit
//  发布为屏幕共享轨道。
//

import ReplayKit
import OSLog

let broadcastLogger = OSLog(subsystem: "com.beidou.aichat", category: "Broadcast")

private enum Constants {
    // App 与扩展共用的 App Group ID，须与两个 target 的 entitlements 保持一致。
    static let appGroupIdentifier = "group.com.beidou.aichat.broadcast"
}

class SampleHandler: RPBroadcastSampleHandler {

    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?

    private var frameCount: Int = 0

    var socketFilePath: String {
        let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier)
        return sharedContainer?.appendingPathComponent("rtc_SSFD").path ?? ""
    }

    override init() {
        super.init()
        if let connection = SocketConnection(filePath: socketFilePath) {
            clientConnection = connection
            setupConnection()

            uploader = SampleUploader(connection: connection)
        }
        os_log(.debug, log: broadcastLogger, "%{public}s", socketFilePath)
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 用户开始录屏。
        frameCount = 0

        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        // 监听主 App 发来的停止请求，使 App 内的“停止共享”按钮可以结束系统录屏。
        observeStopRequest()
        openConnection()
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        // 用户结束录屏。
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            uploader?.send(sample: sampleBuffer)
        default:
            break
        }
    }
}

private extension SampleHandler {

    func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            os_log(.debug, log: broadcastLogger, "client connection did close \(String(describing: error))")

            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                // 用 NSError 时系统提示更友好
                let JMScreenSharingStopped = 10001
                let customError = NSError(domain: RPRecordingErrorDomain, code: JMScreenSharingStopped, userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"])
                self?.finishBroadcastWithError(customError)
            }
        }
    }

    func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else {
                return
            }

            timer.cancel()
        }

        timer.resume()
    }

    /// 监听主 App 的“请求停止录屏”Darwin 通知，收到后结束广播。
    func observeStopRequest() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                let stopped = NSError(domain: RPRecordingErrorDomain, code: 10001, userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"])
                handler.finishBroadcastWithError(stopped)
            },
            DarwinNotification.broadcastRequestStop.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }
}
