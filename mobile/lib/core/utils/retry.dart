import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Executes [fn] with automatic retry on transient failures.
///
/// Uses exponential backoff with jitter:
///   delay = min(baseDelay * 2^attempt, maxDelay) + jitter
///
/// Only retries on network-related errors (timeout, connection, etc.).
/// Permanent errors (4xx) are thrown immediately.
///
/// Example:
/// ```dart
/// final data = await retryWithBackoff(() => repository.getJobs());
/// ```
Future<T> retryWithBackoff<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 10),
}) async {
  final rng = Random();

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      final isLastAttempt = attempt == maxAttempts - 1;

      // Don't retry on non-transient errors.
      if (!_isRetryable(e) || isLastAttempt) {
        rethrow;
      }

      // Exponential backoff: 1s → 2s → 4s → … capped at maxDelay.
      final exponential = baseDelay * pow(2, attempt).toInt();
      final capped = exponential > maxDelay ? maxDelay : exponential;

      // Add ±25% jitter to prevent thundering-herd.
      final jitterMs = (capped.inMilliseconds * 0.25 * (rng.nextDouble() * 2 - 1)).toInt();
      final delay = capped + Duration(milliseconds: jitterMs);

      if (kDebugMode) {
        debugPrint(
          'retryWithBackoff: attempt ${attempt + 1}/$maxAttempts failed '
          '(${e.runtimeType}), retrying in ${delay.inMilliseconds}ms',
        );
      }

      await Future<void>.delayed(delay);
    }
  }

  // Unreachable — the loop always returns or rethrows.
  throw StateError('retryWithBackoff: exhausted all $maxAttempts attempts');
}

/// Whether [error] is a transient / network error worth retrying.
bool _isRetryable(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        // Retry on 5xx (server errors) and 429 (rate limited).
        return statusCode >= 500 || statusCode == 429;
      default:
        return false;
    }
  }

  // Retry on generic socket / timeout exceptions.
  if (error is TimeoutException) return true;

  return false;
}
