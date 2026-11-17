import 'package:dio/dio.dart';

/// A user-presentable failure.
///
/// Repositories translate low-level exceptions into these so the UI never has
/// to inspect a `DioException`, `SqliteException` or provider-specific error.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause, this.isRetryable = true});

  /// Short, human-readable description shown in the UI.
  final String message;

  /// Underlying error, kept for logging and diagnostics only.
  final Object? cause;

  /// Whether offering a "Retry" action makes sense for this failure.
  final bool isRetryable;

  /// Heading used by error states.
  String get title;

  @override
  String toString() =>
      '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';

  /// Maps an arbitrary error to the closest [AppFailure].
  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => NetworkFailure(
          'The request timed out. Check your connection and try again.',
          cause: error,
        ),
        DioExceptionType.connectionError => NetworkFailure(
          'Could not reach the server. Check your connection and try again.',
          cause: error,
        ),
        DioExceptionType.badResponse => _fromStatusCode(
          error.response?.statusCode,
          error,
        ),
        DioExceptionType.cancel => const CancelledFailure(),
        DioExceptionType.badCertificate => const NetworkFailure(
          'The server certificate could not be verified.',
          cause: null,
          isRetryable: false,
        ),
        DioExceptionType.unknown => NetworkFailure(
          'A network error occurred. Please try again.',
          cause: error,
        ),
      };
    }
    return const UnexpectedFailure();
  }

  static AppFailure _fromStatusCode(int? status, Object cause) {
    if (status == null) {
      return NetworkFailure(
        'The server returned an invalid response.',
        cause: cause,
      );
    }
    if (status == 404) {
      return const NotFoundFailure(
        'That title could not be found.',
        cause: null,
        isRetryable: false,
      );
    }
    if (status == 429) {
      return const RateLimitFailure(
        'AniList is rate limiting requests. Please wait a moment.',
        cause: null,
      );
    }
    if (status >= 500) {
      return ServerFailure(
        'The metadata service is unavailable right now.',
        cause: cause,
      );
    }
    return ServerFailure(
      'The request was rejected (HTTP $status).',
      cause: cause,
    );
  }
}

/// No connectivity, DNS failure, timeout, TLS problem.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause, super.isRetryable = true});

  @override
  String get title => 'Connection problem';
}

/// The remote service returned a 5xx or otherwise unusable response.
final class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {super.cause, super.isRetryable = true});

  @override
  String get title => 'Service unavailable';
}

/// The requested resource does not exist.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(
    super.message, {
    super.cause,
    super.isRetryable = false,
  });

  @override
  String get title => 'Not found';
}

/// Remote rate limiting (HTTP 429).
final class RateLimitFailure extends AppFailure {
  const RateLimitFailure(
    super.message, {
    super.cause,
    super.isRetryable = true,
  });

  @override
  String get title => 'Too many requests';
}

/// The response could not be understood (schema drift, malformed payload).
final class ParseFailure extends AppFailure {
  const ParseFailure(super.message, {super.cause, super.isRetryable = false});

  @override
  String get title => 'Unexpected response';
}

/// The requested capability is not offered by the active provider.
final class UnsupportedFailure extends AppFailure {
  const UnsupportedFailure(super.message)
    : super(cause: null, isRetryable: false);

  @override
  String get title => 'Not supported by this source';
}

/// Local database or file-system failure.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause}) : super(isRetryable: true);

  @override
  String get title => 'Local data problem';
}

/// The operation was cancelled by the user or by navigation.
final class CancelledFailure extends AppFailure {
  const CancelledFailure()
    : super('The request was cancelled.', isRetryable: false);

  @override
  String get title => 'Cancelled';
}

/// Fallback for anything unexpected.
final class UnexpectedFailure extends AppFailure {
  // ignore: use_super_parameters — the super constructor also takes a message.
  const UnexpectedFailure({Object? cause})
    : super('Something went wrong. Please try again.', cause: cause);

  @override
  String get title => 'Something went wrong';
}
