import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../providers/provider_failure.dart';
import '../../providers/provider_redaction.dart';
import 'provider_manifest.dart';

/// One outbound exchange, after the adapter has decided it may happen.
class ManifestTransportRequest {
  const ManifestTransportRequest({
    required this.uri,
    required this.method,
    required this.headers,
    this.body,
    required this.timeout,
    required this.receiveTimeout,
  });

  final Uri uri;
  final String method;
  final Map<String, String> headers;

  /// Already-encoded JSON body, for `POST`.
  final String? body;
  final Duration timeout;
  final Duration receiveTimeout;
}

/// A single hop: no redirect following, no status interpretation.
class ManifestTransportResponse {
  const ManifestTransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;

  /// Lower-cased header names.
  final Map<String, String> headers;

  /// Decoded bytes, streamed so the cap is enforced while reading.
  final Stream<List<int>> body;
}

/// The seam that makes the adapter hermetic in tests.
///
/// The real implementation is [DioManifestTransport]; tests supply a fake and
/// assert on what the adapter *tried* to send. Every security decision lives in
/// [ManifestHttp], above this interface, so a test cannot accidentally bypass
/// the allowlist by using a different transport.
abstract class ManifestTransport {
  Future<ManifestTransportResponse> send(ManifestTransportRequest request);

  /// Releases sockets and timers. Must be idempotent.
  void close();
}

/// Dio-backed transport with redirects disabled, so the adapter performs and
/// checks every hop itself.
class DioManifestTransport implements ManifestTransport {
  DioManifestTransport({Dio? dio, this.providerId = 'manifest'})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              followRedirects: false,
              validateStatus: (int? _) => true,
              responseType: ResponseType.stream,
              headers: <String, Object?>{'Accept': 'application/json'},
            ),
          );

  final Dio _dio;
  final String providerId;
  bool _closed = false;

  @override
  Future<ManifestTransportResponse> send(
    ManifestTransportRequest request,
  ) async {
    if (_closed) {
      throw ProviderCancelled(providerId: providerId);
    }
    final Response<ResponseBody> response = await _dio.request<ResponseBody>(
      request.uri.toString(),
      data: request.body,
      options: Options(
        method: request.method,
        headers: <String, Object?>{
          ...request.headers,
          if (request.body != null) 'Content-Type': 'application/json',
        },
        followRedirects: false,
        validateStatus: (int? _) => true,
        responseType: ResponseType.stream,
        sendTimeout: request.timeout,
        receiveTimeout: request.receiveTimeout,
      ),
    );

    final ResponseBody? body = response.data;
    return ManifestTransportResponse(
      statusCode: response.statusCode ?? 0,
      headers: <String, String>{
        for (final MapEntry<String, List<String>> entry
            in response.headers.map.entries)
          entry.key.toLowerCase(): entry.value.join(', '),
      },
      body: body?.stream ?? const Stream<List<int>>.empty(),
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _dio.close(force: true);
  }
}

/// Caps how many manifest requests a process may have in flight.
class ManifestRequestGate {
  ManifestRequestGate(this.maxConcurrent);

  /// The documented app-wide cap (PROVIDER_MANIFEST.md §8.2).
  static final ManifestRequestGate shared = ManifestRequestGate(4);

  final int maxConcurrent;
  int _active = 0;
  final List<Completer<void>> _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active >= maxConcurrent) {
      final Completer<void> completer = Completer<void>();
      _waiting.add(completer);
      await completer.future;
    }
    _active++;
    try {
      return await operation();
    } finally {
      _active--;
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      }
    }
  }

  /// Number of operations currently in flight, for tests and diagnostics.
  int get active => _active;
}

/// Enforces the network envelope of `docs/PROVIDER_MANIFEST.md` §5:
/// origin allowlist on parsed URIs, manual redirects, decoded-byte caps,
/// timeouts, pacing, one idempotent retry, and status interpretation.
///
/// Everything that could send a request goes through [requestJson]. There is no
/// other egress path in the manifest adapter.
class ManifestHttp {
  ManifestHttp({
    required this.providerId,
    required this.net,
    required this.errors,
    required this.transport,
    required Set<Uri> allowedOrigins,
    ManifestRequestGate? gate,
    Future<void> Function(Duration)? delay,
    DateTime Function()? clock,
  }) : _allowedOrigins = <String>{
         for (final Uri origin in allowedOrigins) _originKey(origin),
       },
       _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now {
    _gate = gate;
  }

  final String providerId;
  final ManifestNet net;
  final ManifestErrorPolicy errors;
  final ManifestTransport transport;
  late final ManifestRequestGate? _gate;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _clock;

  /// Normalised `https://host:port` keys. Ports are folded so `https://x` and
  /// `https://x:443` are the same origin.
  final Set<String> _allowedOrigins;

  DateTime? _lastRequestAt;
  bool _closed = false;
  final Completer<void> _closedSignal = Completer<void>();

  /// The effective allowlist, for diagnostics and tests.
  Set<String> get allowedOrigins => Set<String>.unmodifiable(_allowedOrigins);

  /// Performs one logical request (which may include redirect hops) and returns
  /// the decoded JSON document.
  ///
  /// Throws [ProviderFailure] for every failure mode in §8.1. Never returns a
  /// partially decoded body, and never includes a URL or header value in a
  /// message.
  Future<Object?> requestJson({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
    required int maxBytes,
    required List<int> notFoundStatus,
    bool enableRetry = true,
  }) async {
    if (_closed) throw ProviderCancelled(providerId: providerId);
    final Duration budget = timeout > Duration.zero
        ? timeout
        : Duration(milliseconds: net.timeoutMs);
    final int permittedBytes = maxBytes > 0 ? maxBytes : net.maxResponseBytes;
    int attempts = 0;

    while (true) {
      attempts++;
      try {
        return await _attempt(
          uri: uri,
          method: method,
          headers: headers,
          body: body,
          timeout: budget,
          maxBytes: permittedBytes,
          notFoundStatus: notFoundStatus,
        );
      } on ProviderFailure catch (failure) {
        final bool retryable =
            enableRetry &&
            method == 'GET' &&
            attempts == 1 &&
            (failure is ProviderTimeout ||
                (failure is ProviderUpstreamError &&
                    failure.isRetryable &&
                    (failure.status == null || failure.status! >= 500)));
        if (!retryable) rethrow;
        // One retry, 500 ms plus jitter (§8.2). A second failure is final.
        await _delay(Duration(milliseconds: 500 + _clock().microsecond % 250));
      }
    }
  }

  /// Performs a probe exchange and returns the final status code.
  ///
  /// Used by `probe()`, which only needs the status line: the body is never
  /// read. The allowlist, redirects, pacing and cancellation rules are the same
  /// as [requestJson], so a probe cannot reach anywhere a search could not.
  Future<int> requestStatus({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    if (_closed) throw ProviderCancelled(providerId: providerId);
    if (!isAllowedRequestUri(uri)) {
      throw ProviderOriginRejected(
        providerId: providerId,
        message:
            'The source tried to reach ${ProviderRedaction.describeUri(uri)}, '
            'which it did not declare.',
      );
    }
    await _pace();

    Uri current = uri;
    for (int hop = 0; hop <= net.maxRedirects; hop++) {
      final ManifestTransportResponse response =
          await _send(
            ManifestTransportRequest(
              uri: current,
              method: method,
              headers: headers,
              timeout: timeout,
              receiveTimeout: timeout,
            ),
          ).timeout(
            timeout,
            onTimeout: () => throw ProviderTimeout(providerId: providerId),
          );
      if (!_isRedirect(response.statusCode)) return response.statusCode;

      final String? location = response.headers['location'];
      if (location == null || location.isEmpty || hop == net.maxRedirects) {
        throw ProviderUpstreamError(
          providerId: providerId,
          status: response.statusCode,
          message: 'The source redirected too many times.',
        );
      }
      final Uri next = current.resolve(location);
      if (!isAllowedRequestUri(next)) {
        throw ProviderOriginRejected(
          providerId: providerId,
          message:
              'The source redirected to a host it did not declare, which NEXUS '
              'refused to follow.',
        );
      }
      current = next;
    }
    throw ProviderUpstreamError(providerId: providerId);
  }

  /// Validates a media URL (variant or subtitle) before it reaches the player.
  ///
  /// Over HTTPS only, at most 2048 characters, no control characters, and the
  /// host must be an allowed origin or match `net.mediaHosts`. Returns `null`
  /// when the URL is not acceptable — callers drop the item.
  Uri? validateMediaUri(Uri uri) {
    if (uri.scheme != 'https') return null;
    if (!uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    final String raw = uri.toString();
    if (raw.length > 2048) return null;
    for (final int unit in raw.codeUnits) {
      if (unit < 0x20 || unit == 0x7f) return null;
    }
    if (_allowedOrigins.contains(_originKey(uri))) return uri;
    if (_matchesMediaHost(uri.host)) return uri;
    return null;
  }

  /// Whether [uri] may receive a manifest-built request.
  bool isAllowedRequestUri(Uri uri) {
    if (uri.scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.host.isEmpty) return false;
    return _allowedOrigins.contains(_originKey(uri));
  }

  /// Releases the transport and signals in-flight work to stop.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_closedSignal.isCompleted) _closedSignal.complete();
    transport.close();
  }

  bool get isClosed => _closed;

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Object?> _attempt({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    required String? body,
    required Duration timeout,
    required int maxBytes,
    required List<int> notFoundStatus,
  }) async {
    if (!isAllowedRequestUri(uri)) {
      throw ProviderOriginRejected(
        providerId: providerId,
        message:
            'The source tried to reach ${ProviderRedaction.describeUri(uri)}, '
            'which it did not declare.',
      );
    }

    await _pace();

    final Future<Object?> operation = _followRedirects(
      uri: uri,
      method: method,
      headers: headers,
      body: body,
      maxBytes: maxBytes,
      notFoundStatus: notFoundStatus,
      timeout: timeout,
    );

    return _raceClosed(
      operation.timeout(
        timeout,
        onTimeout: () => throw ProviderTimeout(providerId: providerId),
      ),
    );
  }

  Future<Object?> _raceClosed(Future<Object?> operation) {
    if (_closed) {
      return Future<Object?>.error(ProviderCancelled(providerId: providerId));
    }
    return Future.any<Object?>(<Future<Object?>>[
      operation,
      _closedSignal.future.then<Object?>(
        (_) => throw ProviderCancelled(providerId: providerId),
      ),
    ]);
  }

  Future<Object?> _followRedirects({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    required String? body,
    required int maxBytes,
    required List<int> notFoundStatus,
    required Duration timeout,
  }) async {
    Uri current = uri;
    Map<String, String> currentHeaders = headers;
    String currentMethod = method;
    String? currentBody = body;

    for (int hop = 0; hop <= net.maxRedirects; hop++) {
      final ManifestTransportResponse response = await _send(
        ManifestTransportRequest(
          uri: current,
          method: currentMethod,
          headers: currentHeaders,
          body: currentBody,
          timeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      if (_isRedirect(response.statusCode)) {
        final String? location = response.headers['location'];
        if (location == null || location.isEmpty) {
          throw ProviderUpstreamError(
            providerId: providerId,
            status: response.statusCode,
            message: 'The source sent a redirect without a destination.',
          );
        }
        if (hop == net.maxRedirects) {
          throw ProviderUpstreamError(
            providerId: providerId,
            status: response.statusCode,
            message: 'The source redirected too many times.',
          );
        }
        final Uri next = current.resolve(location);
        if (next.scheme != 'https') {
          throw ProviderOriginRejected(
            providerId: providerId,
            message:
                'The source redirected to a non-HTTPS address, which NEXUS '
                'refused to follow.',
          );
        }
        if (!isAllowedRequestUri(next)) {
          throw ProviderOriginRejected(
            providerId: providerId,
            message:
                'The source redirected to ${ProviderRedaction.describeUri(next)}, '
                'which it did not declare.',
          );
        }
        if (_originKey(next) != _originKey(current)) {
          // Credentials are never forwarded across origins.
          currentHeaders = <String, String>{
            for (final MapEntry<String, String> entry in headers.entries)
              if (entry.key.toLowerCase() == 'accept') entry.key: entry.value,
          };
        }
        if (response.statusCode == 303) {
          currentMethod = 'GET';
          currentBody = null;
        }
        current = next;
        continue;
      }

      return _readResponse(
        response,
        method: currentMethod,
        notFoundStatus: notFoundStatus,
        maxBytes: maxBytes,
      );
    }
    throw ProviderUpstreamError(providerId: providerId);
  }

  Future<Object?> _readResponse(
    ManifestTransportResponse response, {
    required String method,
    required List<int> notFoundStatus,
    required int maxBytes,
  }) async {
    final int status = response.statusCode;
    if (status >= 200 && status < 300) {
      final List<int> bytes = await _readCapped(response.body, maxBytes);
      return _decode(bytes);
    }

    // Drain nothing: the failure is decided from status and headers alone.
    if (notFoundStatus.contains(status)) {
      throw ProviderNotFound(providerId: providerId);
    }
    if (errors.unauthorisedStatus.contains(status)) {
      throw ProviderAuthRejected(providerId: providerId);
    }
    if (errors.rateLimitedStatus.contains(status)) {
      throw ProviderRateLimited(
        providerId: providerId,
        retryAfter: _retryAfter(response.headers),
      );
    }
    if (status == 451) {
      throw ProviderGeoRestricted(providerId: providerId);
    }
    if (status >= 400) {
      final bool retryable =
          method == 'GET' && (status == 408 || status == 425);
      throw ProviderUpstreamError(
        providerId: providerId,
        status: status,
        message: retryable
            ? 'The source is busy. Try again in a moment.'
            : 'The source returned an error (HTTP $status).',
      );
    }
    throw ProviderUpstreamError(
      providerId: providerId,
      status: status,
      message: 'The source returned an unexpected status (HTTP $status).',
    );
  }

  Future<T> _throughGate<T>(Future<T> Function() operation) {
    final ManifestRequestGate? gate = _gate;
    return gate == null ? operation() : gate.run<T>(operation);
  }

  Future<ManifestTransportResponse> _send(ManifestTransportRequest request) {
    return _throughGate<ManifestTransportResponse>(() async {
      try {
        return await transport.send(request);
      } on ProviderFailure {
        rethrow;
      } catch (error) {
        // Socket errors, TLS failures and client bugs are mapped once, here, so
        // no raw exception can escape the manifest adapter.
        throw ProviderUpstreamError(
          providerId: providerId,
          message: 'The source could not be reached.',
          retryable: false,
          cause: error,
        );
      }
    });
  }

  Future<List<int>> _readCapped(Stream<List<int>> stream, int maxBytes) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    int total = 0;
    await for (final List<int> chunk in stream) {
      total += chunk.length;
      if (total > maxBytes) {
        throw ProviderParseFailure(
          providerId: providerId,
          message:
              'The source sent more than ${(maxBytes / 1024).round()} KiB of '
              'JSON, which exceeds its declared limit.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Object? _decode(List<int> bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw ProviderParseFailure(
        providerId: providerId,
        message: 'The source returned a response that was not valid UTF-8.',
      );
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ProviderParseFailure(
        providerId: providerId,
        message: 'The source returned a response that was not valid JSON.',
      );
    }
  }

  Future<void> _pace() async {
    final int interval = net.minRequestIntervalMs;
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

  Duration _retryAfter(Map<String, String> headers) {
    final String? raw = headers[errors.retryAfterHeader.toLowerCase()];
    int seconds = 1;
    if (raw != null) {
      final int? parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed > 0) {
        seconds = parsed;
      } else {
        // HTTP-date form: clamp to the configured maximum rather than parse a
        // date we cannot trust.
        seconds = errors.maxRetryAfterSeconds;
      }
    }
    final int capped = seconds.clamp(1, errors.maxRetryAfterSeconds);
    return Duration(seconds: capped);
  }

  bool _matchesMediaHost(String host) {
    final String lower = host.toLowerCase();
    for (final String pattern in net.mediaHosts) {
      if (pattern.startsWith('*.')) {
        final String suffix = pattern.substring(2);
        if (lower.endsWith('.$suffix')) return true;
      } else if (lower == pattern) {
        return true;
      }
    }
    return false;
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static String _originKey(Uri uri) {
    final int port = uri.hasPort ? uri.port : 443;
    return 'https://${uri.host.toLowerCase()}:$port';
  }
}
