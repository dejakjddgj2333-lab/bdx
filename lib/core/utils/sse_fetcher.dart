import 'dart:async';

/// 跨平台实时 SSE 流获取接口
abstract class SseFetcher {
  /// 发送 POST 请求并实时返回字符流
  Stream<String> fetchStream({
    required String url,
    required Map<String, dynamic> body,
    String? token,
  });
}
