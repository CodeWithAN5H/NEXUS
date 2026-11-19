import 'dart:async';

import '../../core/errors/app_failure.dart';

/// The typed failure taxonomy every provider must use.
///
/// Normative table: `docs/PROVIDERS.md` §8. Providers never throw raw
/// exceptions across the contract boundary; the resolver wraps anything else
/// with [ProviderFailure.from]. Messages are copy for humans — callers should
/// branch on the subtype, never on the text.
sealed class ProviderFailure implements Exception {
  const ProviderFailure({
    required this.providerId,
    required this.message,
    this.isRetryable = false,
    this.cause,
  });

  /// Wraps an arbitrary error at the contract boundary.
  factory ProviderFailure.from(Object error, {required String providerId}) {
    if (error is ProviderFailure) return error;
    if (error is TimeoutException) {
      return ProviderTimeout(providerId: providerId, cause: error);
    }
    if (error is AppFailure) {
      return ProviderUpstreamError(
        providerId: providerId,
        message: error.message,
        cause: error,
      );
    }
    return ProviderParseFailure(
      providerId: providerId,
      message: 'The source returned an unexpected response.',
      cause: error,
    );
  }

  /// Id of the provider that failed.
  final String providerId;

  /// User-presentable text. Never includes credentials, headers or stream URLs.
  final String message;

  final bool isRetryable;

  /// Underlying error for local diagnostics only.
  final Object? cause;

  /// Stable machine code for diagnostics and tests.
  String get code;

  /// The closest [AppFailure] for the existing error UI.
  AppFailure toAppFailure() {
    return switch (this) {
      ProviderNotConfigured() => UnsupportedFailure(message),
      ProviderAuthRejected() => UnsupportedFailure(message),
      ProviderUnsupported() => UnsupportedFailure(message),
      ProviderGeoRestricted() => UnsupportedFailure(message),
      ProviderOriginRejected() => UnsupportedFailure(message),
      ProviderNotFound() => NotFoundFailure(message, cause: cause),
      ProviderRateLimited() => RateLimitFailure(message, cause: cause),
      ProviderTimeout() => NetworkFailure(message, cause: cause),
      ProviderUpstreamError() => NetworkFailure(message, cause: cause),
      ProviderParseFailure() => ParseFailure(message, cause: cause),
      ProviderInvalidStream() => ParseFailure(message, cause: cause),
      ProviderManifestInvalid() => ParseFailure(message, cause: cause),
      ProviderCancelled() => const CancelledFailure(),
    };
  }

  @override
  String toString() => 'ProviderFailure($code, $providerId): $message';
}

/// The provider needs configuration before it can serve requests.
final class ProviderNotConfigured extends ProviderFailure {
  const ProviderNotConfigured({
    required super.providerId,
    super.message = 'Set this source up in Settings → Sources before using it.',
    super.cause,
  });

  @override
  String get code => 'provider.notConfigured';
}

/// The provider refused the supplied credentials.
final class ProviderAuthRejected extends ProviderFailure {
  const ProviderAuthRejected({
    required super.providerId,
    super.message =
        'The source rejected your sign-in. Replace its credentials and try '
        'again.',
    super.cause,
  });

  @override
  String get code => 'provider.authRejected';
}

/// The requested title or episode does not exist at this provider.
final class ProviderNotFound extends ProviderFailure {
  const ProviderNotFound({
    required super.providerId,
    super.message = 'This source does not have that title or episode.',
    super.cause,
  });

  @override
  String get code => 'provider.notFound';
}

/// The provider is rate limiting requests.
final class ProviderRateLimited extends ProviderFailure {
  const ProviderRateLimited({
    required super.providerId,
    required this.retryAfter,
    super.message = 'This source is limiting requests. Please wait a moment.',
    super.cause,
  }) : super(isRetryable: true);

  final Duration retryAfter;

  @override
  String get code => 'provider.rateLimited';
}

/// The provider is not available in the user's region.
final class ProviderGeoRestricted extends ProviderFailure {
  const ProviderGeoRestricted({
    required super.providerId,
    super.message = 'Not available in this region.',
    super.cause,
  });

  @override
  String get code => 'provider.geoRestricted';
}

/// The provider's upstream returned an unusable response (HTTP n, socket error).
final class ProviderUpstreamError extends ProviderFailure {
  const ProviderUpstreamError({
    required super.providerId,
    this.status,
    super.message = 'The source is unavailable right now.',
    super.cause,
    bool retryable = true,
  }) : super(isRetryable: retryable);

  /// HTTP status when there was one.
  final int? status;

  @override
  String get code => 'provider.upstream';
}

/// The provider took too long to answer.
final class ProviderTimeout extends ProviderFailure {
  const ProviderTimeout({
    required super.providerId,
    super.message = 'The source took too long to respond.',
    super.cause,
  }) : super(isRetryable: true);

  @override
  String get code => 'provider.timeout';
}

/// The provider's response could not be understood — a provider bug, reported
/// honestly rather than as an empty result.
final class ProviderParseFailure extends ProviderFailure {
  const ProviderParseFailure({
    required super.providerId,
    super.message = 'The source returned an unexpected response.',
    super.cause,
  });

  @override
  String get code => 'provider.parse';
}

/// The provider does not offer the requested capability.
final class ProviderUnsupported extends ProviderFailure {
  const ProviderUnsupported({
    required super.providerId,
    required this.feature,
    super.cause,
  }) : super(message: 'This source has no $feature.');

  final String feature;

  @override
  String get code => 'provider.unsupported';
}

/// The user left the screen; the operation was abandoned.
final class ProviderCancelled extends ProviderFailure {
  const ProviderCancelled({
    required super.providerId,
    super.message = 'The request was cancelled.',
    super.cause,
  });

  @override
  String get code => 'provider.cancelled';
}

/// A request would have left the provider's declared origins.
final class ProviderOriginRejected extends ProviderFailure {
  const ProviderOriginRejected({
    required super.providerId,
    super.message = 'The source tried to reach a host it did not declare.',
    super.cause,
  });

  @override
  String get code => 'provider.originRejected';
}

/// A resolved stream URL failed validation (scheme, host, length).
final class ProviderInvalidStream extends ProviderFailure {
  const ProviderInvalidStream({
    required super.providerId,
    super.message = 'This source returned no playable stream.',
    super.cause,
  });

  @override
  String get code => 'provider.invalidStream';
}

/// A stored manifest no longer validates; only its provider is disabled.
final class ProviderManifestInvalid extends ProviderFailure {
  const ProviderManifestInvalid({
    required super.providerId,
    super.message = 'This source\'s manifest is invalid and was disabled.',
    super.cause,
  });

  @override
  String get code => 'provider.manifestInvalid';
}
