import 'package:dio/dio.dart';

/// Shared mapping from a [DioException] to a safe, user-facing error message.
///
/// Resolution order:
/// 1. If the backend returned a JSON body with a top-level `message`, that
///    message is authoritative (business rule, conflict, validation, not-found,
///    authorization — the backend writes these deliberately).
/// 2. If the backend returned `errors: { field: [...] }` (model validation),
///    the first string error value is surfaced so the real reason is not lost.
/// 3. If the request failed before any HTTP response (backend offline, timeout,
///    connection refused), a network-safe message is returned — never a raw
///    DioException / stack trace.
/// 4. Otherwise `null`, so the caller falls back to its own feature-specific
///    friendly message.
String? messageForError(DioException e) {
  final data = e.response?.data;

  if (data is Map) {
    if (data['message'] is String) {
      final message = data['message'] as String;
      if (message.trim().isNotEmpty) return message;
    }

    // Model validation replies: { errors: { Field: ["reason", ...] } } with no
    // top-level message. Without this the reason is dropped and every failure
    // (duplicate username, out-of-range value) surfaces as the generic
    // fallback.
    final errors = data['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is String && value.trim().isNotEmpty) return value;
        if (value is List) {
          final first = value.firstWhere(
            (item) => item is String && item.trim().isNotEmpty,
            orElse: () => null,
          );
          if (first is String) return first;
        }
      }
    }
  }

  // No HTTP response at all — the failure happened before the backend could
  // answer (server down, wrong address, timeout, no connectivity). These are
  // NOT the backend's fault and must not look like a server error.
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Cannot connect to the server. Check your connection and try again.';
  }

  return null;
}
