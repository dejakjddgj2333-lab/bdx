import 'sse_fetcher.dart';

/// 非 Web 平台不提供 fetch 实现，统一在 Repository 中使用 dio
class SseFetcherImpl implements SseFetcher {
  @override
  Stream<String> fetchStream({
    required String url,
    required Map<String, dynamic> body,
    String? token,
  }) {
    throw UnsupportedError('SSE fetch 仅在 Web 端使用');
  }
}

SseFetcher createSseFetcher() => SseFetcherImpl();
