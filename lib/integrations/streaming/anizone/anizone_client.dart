/// HTTP access to AniZone.
///
/// One client owns the per-provider network envelope so nothing else in the
/// app has to know how AniZone is reached: a fixed User-Agent (the CDN answers
/// `403` without one), conservative pacing, bounded response sizes, one retry
/// for an idempotent read, and a cookie jar for the Livewire continuation.
///
/// Nothing here logs a request header, a cookie or a stream URL.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../providers/provider_failure.dart';

/// Dio-backed AniZone transport.
class AniZoneClient {
  AniZoneClient({
    Dio? dio,
    this.providerId = defaultProviderId,
    this.baseUrl = defaultBaseUrl,
    String? userAgent,
    this.minRequestInterval = const Duration(milliseconds: 250),
    this.requestTimeout = const Duration(seconds: 15),
    this.maxResponseBytes = 4 * 1024 * 1024,
    Future<void> Function(Duration)? delay,
    DateTime Function()? clock,
  }) : _dio = dio ?? Dio(),
       _userAgent = userAgent ?? defaultUserAgent,
       _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  static const String defaultProviderId = 'anizone';
  static const String defaultBaseUrl = 'https://anizone.to';

  /// A mobile Chrome identity. AniZone's CDN answers `403` to requests with no
  /// User-Agent, so the same value is sent to the site and to the media host.
  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Mobile Safari/537.36';

  final String providerId;
  final String baseUrl;
  final Duration minRequestInterval;
  final Duration requestTimeout;
  final int maxResponseBytes;

  final Dio _dio;
  final String _userAgent;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _clock;

  final Map<String, String> _cookies = <String, String>{};
  DateTime? _lastRequestAt;
  bool _closed = false;

  /// The User-Agent the player must send with the stream itself.
  String get userAgent => _userAgent;

  bool get isClosed => _closed;

  /// `GET /anime?search=<q>`.
  Future<String> fetchSearch(String query) {
    return _getText(
      Uri.parse('$baseUrl/anime?search=${Uri.encodeQueryComponent(query)}'),
    );
  }

  /// `GET /anime/<slug>` — identity, first episode page and paging state.
  Future<String> fetchSeriesPage(String slug) {
    return _getText(Uri.parse('$baseUrl/anime/$slug'), slug: slug);
  }

  /// `GET /anime/<slug>/<episode>` — the page that carries the player payload.
  Future<String> fetchEpisodePage(String slug, int episode) {
    return _getText(Uri.parse('$baseUrl/anime/$slug/$episode'), slug: slug);
  }

  /// `POST /livewire/update` — the site's own episode pagination.
  Future<String> fetchEpisodePageContinuation({
    required String slug,
    required String snapshot,
    required String csrfToken,
    required String cursor,
  }) async {
    return _request(
      method: 'POST',
      uri: Uri.parse('$baseUrl/livewire/update'),
      body: jsonEncode(<String, Object?>{
        'components': <Object?>[
          <String, Object?>{
            'snapshot': snapshot,
            'updates': <String, Object?>{},
            'calls': <Object?>[
              <String, Object?>{
                'path': '',
                'method': 'loadPage',
                'params': <Object?>[cursor],
              },
            ],
          },
        ],
      }),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'X-Livewire': '',
        'X-CSRF-TOKEN': csrfToken,
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': baseUrl,
        'Referer': '$baseUrl/anime/$slug',
      },
      retry: false,
    );
  }

  /// Fetches a media playlist from the CDN with the required User-Agent.
  ///
  /// Only `https` URLs are accepted, and cookies are deliberately not sent: the
  /// media host is a different origin from AniZone.
  Future<String> fetchPlaylist(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw ProviderInvalidStream(
        providerId: providerId,
        message: 'The source returned an invalid stream address.',
      );
    }
    return _request(
      method: 'GET',
      uri: uri,
      retry: true,
      maxBytes: 1024 * 1024,
    );
  }

  /// Releases the HTTP client. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    _dio.close(force: true);
  }

  Future<String> _getText(Uri uri, {String? slug}) {
    return _request(
      method: 'GET',
      uri: uri,
      retry: true,
      headers: <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        if (slug != null) 'Referer': '$baseUrl/anime/$slug',
      },
    );
  }

  Future<String> _request({
    required String method,
    required Uri uri,
    Map<String, String> headers = const <String, String>{},
    String? body,
    required bool retry,
    int? maxBytes,
  }) async {
    if (_closed) throw ProviderCancelled(providerId: providerId);

    ProviderFailure? lastFailure;
    for (int attempt = 0; attempt < (retry ? 2 : 1); attempt++) {
      try {
        await _pace();
        return await _attempt(
          method: method,
          uri: uri,
          headers: headers,
          body: body,
          maxBytes: maxBytes ?? maxResponseBytes,
        );
      } on ProviderFailure catch (failure) {
        lastFailure = failure;
        final bool retryable =
            retry &&
            attempt == 0 &&
            (failure is ProviderTimeout ||
                (failure is ProviderUpstreamError &&
                    failure.isRetryable &&
                    (failure.status == null || failure.status! >= 500)));
        if (!retryable) rethrow;
        await _delay(const Duration(milliseconds: 500));
      }
    }
    throw lastFailure ?? ProviderUpstreamError(providerId: providerId);
  }

  Future<String> _attempt({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String? body,
    required int maxBytes,
  }) async {
    final Response<ResponseBody> response;
    try {
      response = await _dio.request<ResponseBody>(
        uri.toString(),
        data: body,
        options: Options(
          method: method,
          responseType: ResponseType.stream,
          validateStatus: (int? _) => true,
          followRedirects: true,
          maxRedirects: 3,
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          headers: <String, Object?>{
            'User-Agent': _userAgent,
            'Accept-Language': 'en-US,en;q=0.9',
            ...headers,
            if (_isSiteRequest(uri) && _cookies.isNotEmpty)
              'Cookie': _cookieHeader(),
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }

    if (_isSiteRequest(uri)) _rememberCookies(response);

    final int status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return _readBody(response.data, maxBytes);
    }
    throw _statusFailure(status, response.headers);
  }

  ProviderFailure _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return ProviderTimeout(providerId: providerId, cause: error);
      case DioExceptionType.cancel:
        return ProviderCancelled(providerId: providerId, cause: error);
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      case DioExceptionType.badResponse:
        return ProviderUpstreamError(
          providerId: providerId,
          message: 'The source could not be reached.',
          retryable: false,
          cause: error,
        );
    }
  }

  ProviderFailure _statusFailure(int status, Headers headers) {
    if (status == 404) return ProviderNotFound(providerId: providerId);
    if (status == 429) {
      return ProviderRateLimited(
        providerId: providerId,
        retryAfter: _retryAfter(headers),
      );
    }
    if (status == 451) return ProviderGeoRestricted(providerId: providerId);
    if (status >= 500) {
      return ProviderUpstreamError(
        providerId: providerId,
        status: status,
        message: 'The source returned an error (HTTP $status).',
      );
    }
    if (status == 403) {
      return ProviderUpstreamError(
        providerId: providerId,
        status: status,
        message:
            'The source refused the request (HTTP 403). It may now require a '
            'sign-in or block this app.',
        retryable: false,
      );
    }
    return ProviderUpstreamError(
      providerId: providerId,
      status: status,
      message: 'The source returned an unexpected status (HTTP $status).',
      retryable: false,
    );
  }

  Duration _retryAfter(Headers headers) {
    final String? raw = headers.value('retry-after');
    final int? seconds = raw == null ? null : int.tryParse(raw.trim());
    return Duration(seconds: (seconds ?? 30).clamp(1, 300));
  }

  Future<String> _readBody(ResponseBody? body, int maxBytes) async {
    if (body == null) {
      throw ProviderParseFailure(
        providerId: providerId,
        message: 'The source returned an empty response.',
      );
    }
    final BytesBuilder builder = BytesBuilder(copy: false);
    int total = 0;
    await for (final List<int> chunk in body.stream) {
      total += chunk.length;
      if (total > maxBytes) {
        throw ProviderParseFailure(
          providerId: providerId,
          message:
              'The source sent more than ${(maxBytes / 1024).round()} KiB in '
              'one response, which is more than expected.',
        );
      }
      builder.add(chunk);
    }
    try {
      return utf8.decode(builder.takeBytes());
    } on FormatException catch (error) {
      throw ProviderParseFailure(
        providerId: providerId,
        message: 'The source returned a response that was not valid UTF-8.',
        cause: error,
      );
    }
  }

  Future<void> _pace() async {
    final int interval = minRequestInterval.inMilliseconds;
    if (interval <= 0) return;
    final DateTime? last = _lastRequestAt;
    if (last != null) {
      final int elapsed = _clock().difference(last).inMilliseconds;
      if (elapsed < interval) {
        await _delay(Duration(milliseconds: interval - elapsed));
      }
    }
    _lastRequestAt = _clock();
  }

  bool _isSiteRequest(Uri uri) => uri.host == Uri.parse(baseUrl).host;

  void _rememberCookies(Response<ResponseBody> response) {
    final List<String> values = response.headers['set-cookie'] ?? <String>[];
    for (final String value in values) {
      final int equals = value.indexOf('=');
      if (equals <= 0) continue;
      final String name = value.substring(0, equals).trim();
      final String cookieValue = value
          .substring(equals + 1)
          .split(';')
          .first
          .trim();
      if (name.isEmpty) continue;
      _cookies[name] = cookieValue;
    }
  }

  String _cookieHeader() => <String>[
    for (final MapEntry<String, String> entry in _cookies.entries)
      '${entry.key}=${entry.value}',
  ].join('; ');
}
