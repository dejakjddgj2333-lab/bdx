// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'sse_fetcher.dart';

/// Web 端使用 XHR onProgress 实时读取 responseText 增量
class SseFetcherImpl implements SseFetcher {
  @override
  Stream<String> fetchStream({
    required String url,
    required Map<String, dynamic> body,
    String? token,
  }) {
    final controller = StreamController<String>.broadcast();
    final xhr = html.HttpRequest();

    xhr.open('POST', url);
    xhr.setRequestHeader('Content-Type', 'application/json');
    if (token != null && token.isNotEmpty) {
      xhr.setRequestHeader('Authorization', 'Bearer $token');
    }
    xhr.responseType = 'text';

    var lastLength = 0;

    void emitNewText() {
      final text = xhr.responseText ?? '';
      if (text.length > lastLength) {
        controller.add(text.substring(lastLength));
        lastLength = text.length;
      }
    }

    xhr.onProgress.listen((_) {
      emitNewText();
    });

    xhr.onLoadEnd.listen((_) {
      emitNewText();
      controller.close();
    });

    xhr.onError.listen((_) {
      controller.addError(Exception('SSE 请求失败: ${xhr.statusText}'));
      controller.close();
    });

    xhr.onTimeout.listen((_) {
      controller.addError(Exception('SSE 请求超时'));
      controller.close();
    });

    xhr.send(jsonEncode(body));

    return controller.stream;
  }
}

SseFetcher createSseFetcher() => SseFetcherImpl();
