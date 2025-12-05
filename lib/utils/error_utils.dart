import 'package:dio/dio.dart';

String formatError(Object err, {String? fallback}) {
  if (err is DioException) {
    final status = err.response?.statusCode;
    final data = err.response?.data;
    String? message;

    if (data is Map) {
      message = data['error']?.toString() ?? data['message']?.toString();
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    message ??= err.message;

    if (status != null && message != null && message.isNotEmpty) {
      return '[$status] $message';
    } else if (message != null && message.isNotEmpty) {
      return message;
    }

    return fallback ?? 'Unexpected network error';
  }

  final msg = err.toString();
  if (msg.isNotEmpty && !msg.contains('Instance of')) {
    return msg;
  }
  return fallback ?? 'Something went wrong';
}

String formatErrorWithContext(
  Object err, {
  required String action,
  List<String> reasons = const [],
  String? fallback,
}) {
  final trimmedAction = action.trim();
  final base = formatError(
    err,
    fallback: fallback ??
        (trimmedAction.isEmpty
            ? 'Something went wrong'
            : 'Unable to $trimmedAction'),
  );
  final message =
      trimmedAction.isEmpty ? base : 'Unable to $trimmedAction: $base';
  return withPossibleReasons(message, reasons: reasons);
}

String withPossibleReasons(
  String message, {
  List<String> reasons = const [],
  String heading = 'Possible reasons:',
}) {
  if (reasons.isEmpty) return message;
  final buffer = StringBuffer(message);
  buffer.writeln();
  buffer.writeln(heading);
  for (final reason in reasons) {
    if (reason.trim().isEmpty) continue;
    buffer.writeln('- ${reason.trim()}');
  }
  return buffer.toString().trimRight();
}
