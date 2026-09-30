/// Formatting rules for contact request responses.
library;

/// Maximum characters of server body echoed in a snackbar error message.
const int contactErrorBodyMaxLength = 200;

/// Formats the complete HTTP result for the on-screen diagnostic panel.
String formatContactResponseSummary({
  required int statusCode,
  required String body,
}) {
  final trimmed = body.trim();
  final resolvedBody = trimmed.isEmpty ? '(empty response body)' : trimmed;

  return 'Status: $statusCode\n$resolvedBody';
}

/// Produces a bounded error message so large server responses do not flood
/// the snackbar.
///
/// Bodies longer than [contactErrorBodyMaxLength] are truncated with an
/// ellipsis, and an empty body falls back to a status-only message.
String formatContactErrorMessage({
  required int statusCode,
  required String body,
}) {
  var responseText = body.trim();

  if (responseText.length > contactErrorBodyMaxLength) {
    responseText = '${responseText.substring(0, contactErrorBodyMaxLength)}...';
  }

  if (responseText.isEmpty) {
    return 'The server returned error $statusCode.';
  }

  return 'The server returned error $statusCode: $responseText';
}
