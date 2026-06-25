import 'dart:async';
import 'dart:io';

import 'package:ali_auth/ali_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 第三方/系统登录结果
class AuthServiceResult {
  final bool success;
  final String? token;
  final String? userIdentifier;
  final String? email;
  final String? nickname;
  final String? error;

  const AuthServiceResult({
    required this.success,
    this.token,
    this.userIdentifier,
    this.email,
    this.nickname,
    this.error,
  });

  factory AuthServiceResult.error(String message) {
    return AuthServiceResult(success: false, error: message);
  }

  @override
  String toString() {
    return 'AuthServiceResult(success: $success, token: $token, error: $error, userIdentifier: $userIdentifier, email: $email, nickname: $nickname)';
  }
}

/// 一键登录预取号（预热）状态。
/// - idle：未开始
/// - preparing：initSdk + 预取号进行中
/// - ready：预取号成功，可秒弹授权页
/// - unavailable：当前环境不支持一键登录（无 SIM / 未开移动数据 / 取号失败等）
enum _AliPrefetchState { idle, preparing, ready, unavailable }

/// 封装 ali_auth 一键登录与 Apple Sign In。
class AuthService {
  static const String _iosAliAuthKey = 'ooq3ZfTWbrnskZw6sEAaZ773Pry7SRzkcOIdcmjDrdAq6WhQgYD1jfZ8Nm6FsFzUD6wShUltdwJPja7dl7c3KsyEHxoW7FipfcplL6vGhNFvvE4MbYIdbYMiT8JfMDi/irurZf1TkeAUXpnslIlItVyjOw2llAXKipAzRxPUuaT64cV6wSo3kOxr0F0Qj67kxHHpnUXHP/qU1d02ZzPVvGYEW1crwe2UIUPVswmD2Lu1EbjyJAvog9PeE229gWLhYML2QFjML9E=';
  static const String _androidAliAuthKey = 'SGQM+deYNMXzzPYIg9BrrSvS2BrVDVRTYT16khExH1pUhTnSJPjohLceh4KHqv8Gax7deLUEHWmWTlYAVJZp16jZrArCbZjGJ6yi9rjWQ999cHi28ax+1SrmwEW5IL/RlNB1Vo+jnEKMiXlOorEktWV8JCOHqEdKdjzcVokc/QZQBvTaCGDnk7cOn6qAEUNqAlnz4QyHWUbhw5/U3bIlqx3987ydomkA7JhpOV2lOmibSzUWjcy3VAcJcHz4rxUbb1XRnIpqg3QPnq3MVGe0tKXlz/SQP6oIwB2tP90ENExmmu11WAkvSQ==';

  /// 是否已经初始化过 ali_auth SDK
  static bool _aliAuthInitialized = false;

  /// 是否已经设置过监听
  static bool _loginListening = false;

  /// 一键登录预取号状态
  static _AliPrefetchState _prefetchState = _AliPrefetchState.idle;

  /// 最近一次预取号失败的原因，[prefetchState] == unavailable 时有效
  static String? _prefetchError;

  /// 等待预取号结果的 completer（点击登录时若仍在 preparing 则 await 它）
  static Completer<bool>? _prefetchCompleter;

  /// 预取号兜底超时计时器（收到 600024/600016/失败码即取消）
  static Timer? _prefetchTimer;

  /// 用户点击一键登录后、等待授权页返回 token 的 completer
  static Completer<AuthServiceResult>? _loginCompleter;

  /// 唤起授权页阶段的超时计时器（授权页弹起 600001 即取消）
  static Timer? _loginTimer;

  /// 调试日志回调：登录页可设置它，把一键登录流程实时显示到界面上。
  static void Function(String msg)? logSink;

  /// 统一日志出口：既打印到控制台，也推给 [logSink] 显示到页面。
  static void _log(String msg) {
    debugPrint('[AliAuth] $msg');
    logSink?.call(msg);
  }

  /// 阿里云一键登录授权页配置。
  ///
  /// 与 App 深色科技感主题保持一致：
  /// - 背景 #010510
  /// - 主按钮使用品牌紫色系（文字）
  /// - 辅助文字使用半透明白色
  /// - 协议链接使用品牌紫色
  static AliAuthModel _defaultConfig() {
    return AliAuthModel(
      _androidAliAuthKey,
      _iosAliAuthKey,
      isDebug: true,
      // 延时登录：initSdk 后不自动弹授权页，改由我们在收到 600024
      // （终端环境检查支持）后手动调用 AliAuth.login() 弹唯一一次。
      // 若用默认的 isDelay=false，iOS 端 initSdk 会自动弹一次授权页，
      // 叠加我们手动的 login() 会重复拉起、重复预取号，导致第二个页面
      // 渲染异常（白底）。
      isDelay: true,
      pageType: PageType.fullPort,
      // 页面背景。
      //
      // ⚠️ 全屏模式(fullPort)下，ali_auth 的 `backgroundColor` 配置键会被插件
      // 的 keyPair 映射到 TXCustomModel.alertContentViewColor（弹窗内容色，
      // 全屏页面无效），真正的全屏背景属性 TXCustomModel.backgroundColor 永远
      // 不会被赋值 —— 这正是「设了深色却仍白底」的根因。
      // 插件源码里全屏背景的唯一有效入口是 `pageBackgroundPath`
      // （keyPair: pageBackgroundPath -> backgroundImage），即用一张图铺满。
      // 因此用一张纯 #010510 的深色背景图覆盖整页；backgroundColor 仅作为
      // Android / 二次弹窗的兜底保留。
      backgroundColor: '#010510',
      // 全屏背景图：iOS 与 Android 都走 Flutter assets 图片路径，插件会转成本地
      // 路径后分别设置 backgroundImage / pageBackgroundDrawable。
      pageBackgroundPath: 'assets/images/auth_bg.png',
      // 状态栏：深色背景 + 白色文字
      statusBarColor: '#010510',
      lightColor: false,
      // 隐藏原生导航栏，保持沉浸
      navHidden: true,
      // Logo：iOS 显示 Flutter assets；Android 暂隐藏避免原生资源缺失
      logoHidden: Platform.isAndroid,
      logoImgPath: Platform.isIOS ? 'assets/images/logo.png' : null,
      logoWidth: 80,
      logoHeight: 80,
      logoOffsetY: 140,
      logoScaleType: ScaleType.fitCenter,
      // Slogan：运营商认证提示
      sloganHidden: false,
      sloganText: '本机号码认证',
      sloganTextColor: '#A6FFFFFF',
      sloganTextSize: 14,
      sloganOffsetY: 240,
      // 掩码栏：大号白色手机号
      numberColor: '#FFFFFF',
      numberSize: 28,
      numFieldOffsetY: 300,
      numberLayoutGravity: Gravity.centerHorizntal,
      // 登录按钮：品牌紫文字，后续可替换为圆角渐变背景图
      logBtnText: '本机号码一键登录',
      logBtnTextColor: '#FFFFFF',
      logBtnTextSize: 16,
      logBtnWidth: 320,
      logBtnHeight: 52,
      logBtnOffsetY: 400,
      logBtnMarginLeftAndRight: 28,
      logBtnLayoutGravity: Gravity.centerHorizntal,
      // 登录按钮背景：正常态、不可按态、按下态。
      // iOS 走 Flutter assets（插件 changeUriPathToImage 只能读 flutter_assets，
      // 读不到 Xcode Assets.xcassets）；Android 走 drawable 资源名。
      logBtnBackgroundPath: Platform.isIOS
          ? 'assets/images/login_btn_normal.png,assets/images/login_btn_unable.png,assets/images/login_btn_press.png'
          : 'login_btn_normal,login_btn_unable,login_btn_press',
      // 切换其他方式：隐藏
      switchAccHidden: true,
      // 协议栏：默认勾选、隐藏复选框、使用品牌紫色协议链接
      privacyState: true,
      checkboxHidden: true,
      protocolColor: '#A6FFFFFF',
      protocolOwnColor: '#8B51EA',
      protocolOwnOneColor: '#8B51EA',
      protocolLayoutGravity: Gravity.centerHorizntal,
      privacyOffsetY_B: 48,
      privacyTextSize: 11,
      privacyBefore: '登录即代表您已阅读并同意',
      privacyEnd: '',
      vendorPrivacyPrefix: '《',
      vendorPrivacySuffix: '》',
      // 交互
      tapAuthPageMaskClosePage: false,
      autoQuitPage: true,
      autoHideLoginLoading: true,
    );
  }

  /// 进入登录页/首页时调用：初始化 SDK 并预取号（预热）。
  ///
  /// 幂等，可重复调用。预取号结果由 [_ensureListening] 的事件回调写入
  /// [_prefetchState]：成功 -> ready，失败/不支持 -> unavailable。
  /// 这样用户真正点击「一键登录」时，可直接 [AliAuth.login] 秒弹授权页，
  /// 或在不可用时立即转邮箱登录，无需每次现场初始化、预取号。
  static Future<void> prepareAliAuth() async {
    _ensureListening();
    // 已初始化过即已预取过号，无需重复
    if (_aliAuthInitialized) return;
    if (_prefetchState == _AliPrefetchState.preparing) return;

    _prefetchState = _AliPrefetchState.preparing;
    _prefetchError = null;
    _prefetchCompleter = Completer<bool>();
    try {
      // Android：完全无网络时直接判不可用。
      // 注意 checkCellularDataEnable 原生返回的是 {code, msg} 对象而非 bool：
      // code==1 表示有任意可用网络(含 WiFi)，code==0 表示无网络。
      // 一键登录取号实际走运营商网关，这里只拦「完全无网」这种必然失败的情况，
      // 其余交给预取号/授权页事件判定，避免 WiFi 环境被误杀。
      if (Platform.isAndroid) {
        try {
          final net = await AliAuth.checkCellularDataEnable;
          final code = (net is Map) ? net['code'] : net;
          if (code == 0 || code == false) {
            _markPrefetch(false, '无可用网络');
            return;
          }
        } catch (_) {}
      }
      debugPrint('[AliAuth] prepareAliAuth: initSdk 预热');
      _log('开始预热：initSdk + 预取号…');
      await AliAuth.initSdk(_defaultConfig());
      _aliAuthInitialized = true;
      // initSdk 内部完成 checkEnv + accelerate(预取号)，
      // 结果通过 600024/600016(成功) 或 6000xx(失败) 事件回调更新 _prefetchState。
      // 兜底：部分安卓机型/网络下预取号回调可能迟迟不返回。超时只「解除等待」，
      // 不判定 unavailable —— 因为「没回调」≠「不可用」，硬判不可用会再次把安卓
      // 卡死在邮箱。保持 preparing，点击登录时 preparing 分支会照常唤起授权页，
      // 真正能否取到 token 由授权页事件决定。
      _prefetchTimer?.cancel();
      _prefetchTimer = Timer(const Duration(seconds: 8), () {
        if (_prefetchState == _AliPrefetchState.preparing) {
          _log('预取号超时(8s 无回调)，点击登录将直接尝试唤起授权页');
          final c = _prefetchCompleter;
          if (c != null && !c.isCompleted) c.complete(false);
        }
      });
    } catch (e) {
      _log('预热异常: $e');
      _markPrefetch(false, e.toString());
    }
  }

  /// 一键登录当前是否就绪（预取号成功）。
  static bool get isOneClickReady => _prefetchState == _AliPrefetchState.ready;

  /// 注册全局事件监听（仅一次）。事件分发到两条线：
  /// - 预取号状态机：600024/600016 -> ready，失败码 -> unavailable
  /// - 当前登录请求：600000 -> 成功 token，600001 -> 取消超时，失败/取消码 -> 失败
  static void _ensureListening() {
    if (_loginListening) return;
    AliAuth.loginListen(
      type: false,
      onEvent: (event) async {
        final code = event?['code']?.toString();
        final msg = event?['msg']?.toString() ?? '一键登录失败';
        final hasData = (event?['data']?.toString().isNotEmpty ?? false);
        _log('事件 $code ${msg.isNotEmpty ? msg : ''}${hasData ? ' (含token)' : ''}');

        // 收到任何事件即说明授权页 / SDK 正在正常工作，立即取消「唤起授权页
        // 超时」兜底。否则用户在授权页停留较久（或 iOS 未及时回 600001）时，
        // 超时会先把 completer 以 error 完成，导致随后到达的 600000 token 被
        // 丢弃，表现为「点授权页登录按钮没反应」。
        _loginTimer?.cancel();
        _loginTimer = null;

        switch (code) {
          case '600000': // 获取 token 成功
            final token = event?['data']?.toString();
            _completeLogin(
              token != null && token.isNotEmpty
                  ? AuthServiceResult(success: true, token: token)
                  : AuthServiceResult.error('未获取到登录 token'),
            );
            break;
          case '600024': // 终端环境检查支持
          case '600016': // 预取号成功
            _markPrefetch(true, null);
            break;
          case '600001': // 唤起授权页成功，等待用户操作
            _loginTimer?.cancel();
            break;
          case '600002': // 唤起授权页失败
          case '600004': // 获取运营商配置失败
          case '600005': // 手机终端不安全
          case '600007': // 未检测到 SIM 卡
          case '600008': // 蜂窝网络未开启
          case '600009': // 无法判断运营商
          case '600010': // 未知异常
          case '600011': // 获取 token 失败
          case '600012': // 预取号失败
          case '600013': // 运营商维护升级
          case '600014': // 达到最大调用次数
          case '600015': // 接口超时
          case '600017': // AppID/Appkey 解析失败
          case '600023': // 自定义控件异常
          case '600025': // 终端检测参数错误
            // 这些表示一键登录不可用
            _markPrefetch(false, '[$code] $msg');
            _completeLogin(AuthServiceResult.error('[$code] $msg'));
            break;
          case '700000': // 用户取消登录
          case '700001': // 用户切换其他登录方式
            _completeLogin(AuthServiceResult.error('[$code] $msg'));
            break;
          default:
            // 700002 点击登录按钮 / 700003 勾选协议 等中间态，忽略
            break;
        }
      },
      onError: (error) {
        _log('onError: $error');
        _markPrefetch(false, error.toString());
        _completeLogin(AuthServiceResult.error(error.toString()));
      },
    );
    _loginListening = true;
  }

  /// 更新预取号状态，并唤醒可能在等待预热结果的点击请求。
  static void _markPrefetch(bool ready, String? error) {
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _prefetchState =
        ready ? _AliPrefetchState.ready : _AliPrefetchState.unavailable;
    _prefetchError = ready ? null : error;
    _log(ready ? '预取号就绪 ✅ 可一键登录' : '预取号不可用 ❌ ${error ?? ''}');
    final c = _prefetchCompleter;
    if (c != null && !c.isCompleted) c.complete(ready);
  }

  /// 完成当前登录请求（若存在）。
  static void _completeLogin(AuthServiceResult result) {
    _loginTimer?.cancel();
    _loginTimer = null;
    final c = _loginCompleter;
    if (c != null && !c.isCompleted) {
      _log('完成登录: success=${result.success}, token=${result.token != null ? '有' : '无'}, err=${result.error ?? '-'}');
      c.complete(result);
    }
  }

  /// 用户点击「一键登录」时调用。
  ///
  /// 预取号(accelerate)只是「加速优化」，并非一键登录的前提——阿里 SDK 明确
  /// 注明「预取号的成功与否不影响一键登录功能」。因此这里只在拿到**明确失败码**
  /// (unavailable) 时才立即转邮箱；其余情况一律尝试唤起授权页，由授权页事件
  /// (600001/600000 或失败码) 决定成败。
  ///
  /// - 已确定不可用(unavailable) -> 立即返回失败，调用方跳邮箱登录；
  /// - 就绪(ready) -> 直接唤起授权页；
  /// - 仍在预取号(preparing) -> 最多等 [waitReady]，到点仍没结果也照常唤起授权页
  ///   （安卓部分机型/网络下预取号回调可能迟迟不返回，但 login 会自行取号，
  ///   不能因此卡死一键登录）。
  static Future<AuthServiceResult> startAliAuthLogin({
    Duration waitReady = const Duration(seconds: 5),
  }) async {
    _log('点击一键登录，当前预取号状态=${_prefetchState.name}');

    // 已拿到明确失败码 -> 直接转邮箱
    if (_prefetchState == _AliPrefetchState.unavailable) {
      _log('一键登录已判定不可用，转邮箱: ${_prefetchError ?? ''}');
      return AuthServiceResult.error(_prefetchError ?? '一键登录不可用，请使用邮箱登录');
    }

    // 尚未预热过，补一次（不阻塞）
    if (_prefetchState == _AliPrefetchState.idle) {
      unawaited(prepareAliAuth());
    }

    // 预取号仍在进行：最多等 waitReady 看能否就绪或判失败
    if (_prefetchState == _AliPrefetchState.preparing) {
      _log('预取号进行中，最多等待 ${waitReady.inSeconds}s…');
      final c = _prefetchCompleter;
      if (c != null) {
        await c.future.timeout(waitReady, onTimeout: () => false);
      }
      // 等待期间若已判明不可用，转邮箱
      if (_prefetchState == _AliPrefetchState.unavailable) {
        _log('预取号判定不可用，转邮箱: ${_prefetchError ?? ''}');
        return AuthServiceResult.error(_prefetchError ?? '一键登录不可用，请使用邮箱登录');
      }
      // 仍未就绪：不放弃，下面照常唤起授权页（login 会自行取号）
      if (_prefetchState != _AliPrefetchState.ready) {
        _log('预取号未在 ${waitReady.inSeconds}s 内就绪，仍尝试唤起授权页');
      }
    }

    // 唤起授权页，等待用户点击拿 token
    final completer = Completer<AuthServiceResult>();
    _loginCompleter = completer;

    // ⚠️ 千万不要 await AliAuth.login()！
    // iOS 原生端的 login 分支(AliAuthPlugin.m)只调 loginWithModel，
    // 从不调用 Flutter 的 result 回调，因此 invokeMethod('login') 返回的
    // Future 永远不会完成。若 await 它，本函数会永久卡在这里、走不到
    // `return completer.future`，调用方拿到的就是一个永不 resolve 的 future——
    // 表现为：600000 已拿到 token、completer 也已完成，页面却始终收不到结果
    // （「点授权页登录按钮没反应」的真正根因）。
    // 登录结果统一由事件监听 onEvent 里的 _completeLogin(completer) 回传。
    _log('调用 AliAuth.login() 弹授权页（预取号状态=${_prefetchState.name}）');
    unawaited(AliAuth.login().catchError((e) {
      _log('AliAuth.login() 异常: $e');
      _completeLogin(AuthServiceResult.error(e.toString()));
      return null;
    }));

    // 唤起授权页前的超时保护：收到任何事件(如 600001)即取消，不覆盖用户停留时长
    _loginTimer = Timer(const Duration(seconds: 10), () {
      _log('唤起授权页超时(10s 内无任何事件)');
      _completeLogin(AuthServiceResult.error('一键登录唤起授权页超时，请使用邮箱登录'));
    });
    return completer.future;
  }

  /// Apple Sign In（仅 iOS）
  static Future<AuthServiceResult> signInWithApple() async {
    if (!Platform.isIOS) {
      return AuthServiceResult.error('Apple 登录仅支持 iOS');
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      final userIdentifier = credential.userIdentifier;

      if (identityToken == null || userIdentifier == null) {
        return AuthServiceResult.error('Apple 登录授权信息不完整');
      }

      // Apple 只在首次授权时返回姓名和邮箱
      final givenName = credential.givenName;
      final familyName = credential.familyName;
      final nickname = givenName != null || familyName != null
          ? '${givenName ?? ''}${familyName ?? ''}'.trim()
          : null;

      return AuthServiceResult(
        success: true,
        token: identityToken,
        userIdentifier: userIdentifier,
        email: credential.email,
        nickname: nickname,
      );
    } catch (e) {
      return AuthServiceResult.error(e.toString());
    }
  }
}
