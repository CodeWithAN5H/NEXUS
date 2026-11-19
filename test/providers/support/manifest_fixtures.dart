import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexus/integrations/streaming/manifest/manifest_error.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_http.dart';
import 'package:nexus/integrations/streaming/manifest/manifest_validator.dart';
import 'package:nexus/integrations/streaming/manifest/provider_manifest.dart';

/// Hermetic transport: every request is answered from a script, never a socket.
class FakeManifestTransport implements ManifestTransport {
  FakeManifestTransport(this.handler);

  final FutureOr<FakeManifestResponse> Function(
    ManifestTransportRequest request,
  )
  handler;

  /// Every request the adapter actually attempted, in order. Security tests
  /// assert on this list, not on the fake's internal state.
  final List<ManifestTransportRequest> sent = <ManifestTransportRequest>[];

  bool closed = false;

  @override
  Future<ManifestTransportResponse> send(
    ManifestTransportRequest request,
  ) async {
    sent.add(request);
    final FakeManifestResponse response = await handler(request);
    return response.toTransportResponse();
  }

  @override
  void close() {
    closed = true;
  }
}

class FakeManifestResponse {
  FakeManifestResponse._({
    required this.statusCode,
    required this.headers,
    this.body,
    this.bytes,
    this.never = false,
  });

  factory FakeManifestResponse.json(
    Object? body, {
    int status = 200,
    Map<String, String> headers = const <String, String>{},
  }) {
    return FakeManifestResponse._(
      statusCode: status,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  factory FakeManifestResponse.raw(
    String body, {
    int status = 200,
    Map<String, String> headers = const <String, String>{},
  }) {
    return FakeManifestResponse._(
      statusCode: status,
      headers: headers,
      body: body,
    );
  }

  factory FakeManifestResponse.bytes(
    List<int> bytes, {
    int status = 200,
    Map<String, String> headers = const <String, String>{},
  }) {
    return FakeManifestResponse._(
      statusCode: status,
      headers: headers,
      bytes: bytes,
    );
  }

  factory FakeManifestResponse.redirect(String location, {int status = 302}) {
    return FakeManifestResponse._(
      statusCode: status,
      headers: <String, String>{'location': location},
    );
  }

  /// A response that never completes, for timeout tests.
  factory FakeManifestResponse.never() {
    return FakeManifestResponse._(
      statusCode: 200,
      headers: const <String, String>{},
      never: true,
    );
  }

  final int statusCode;
  final Map<String, String> headers;
  final String? body;
  final List<int>? bytes;
  final bool never;

  ManifestTransportResponse toTransportResponse() {
    final Stream<List<int>> stream = never
        ? Completer<List<int>>().future.asStream()
        : Stream<List<int>>.value(
            bytes ?? Uint8List.fromList(utf8.encode(body ?? '')),
          );
    return ManifestTransportResponse(
      statusCode: statusCode,
      headers: <String, String>{
        for (final MapEntry<String, String> entry in headers.entries)
          entry.key.toLowerCase(): entry.value,
      },
      body: stream,
    );
  }
}

/// Reads a committed example from `docs/schema/examples/`.
String manifestExample(String name) =>
    File('docs/schema/examples/$name').readAsStringSync();

/// A decoded copy of the minimal example, for mutation in tests.
Map<String, dynamic> minimalManifest() =>
    jsonDecode(manifestExample('valid-minimal.json')) as Map<String, dynamic>;

Map<String, dynamic> fullManifest() =>
    jsonDecode(manifestExample('valid-full.json')) as Map<String, dynamic>;

/// Deep copy so a mutation cannot leak between tests.
Map<String, dynamic> copyOf(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

/// Validates a mutated document.
ManifestValidationResult validate(
  Map<String, dynamic> manifest, {
  Set<String> builtInIds = const <String>{'sample', 'anilist'},
}) {
  return ManifestValidator(builtInIds: builtInIds)
      .validate(jsonEncode(manifest));
}

/// The comfortable configuration a manifest provider test uses.
const Map<String, String> testConfig = <String, String>{
  'baseUrl': 'https://api.example.com',
  'apiKey': 'unit-test-secret-value',
};

/// Convenience accessor: the failure code at the first error, if any.
String? firstErrorCode(ManifestValidationResult result) =>
    result.errors.isEmpty ? null : result.errors.first.code;

/// True when a failure message leaks any configured secret.
bool leaksSecret(String message) {
  return message.contains('unit-test-secret-value') ||
      message.contains(testConfig['apiKey']!);
}

/// A provider manifest with a `baseUrl`, for interpreter tests.
ProviderManifest parseManifest(
  Map<String, dynamic> document, {
  Set<String> builtInIds = const <String>{'sample', 'anilist'},
}) {
  final ManifestValidationResult result = validate(
    document,
    builtInIds: builtInIds,
  );
  if (result.manifest == null) {
    throw StateError('Fixture did not validate: ${result.errors}');
  }
  return result.manifest!;
}
