/// Validation and payload rules for the Contact Us form.
library;

/// Minimum accepted length of a return name.
const int contactNameMinLength = 2;

/// Minimum accepted length of a question.
const int contactQuestionMinLength = 5;

/// Matches a plain `local@domain.tld` address with no spaces.
final RegExp contactEmailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Validates the return name, returning an error message or null when valid.
String? validateContactName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter your name.';
  }

  if (value.trim().length < contactNameMinLength) {
    return 'The name must contain at least two characters.';
  }

  return null;
}

/// Validates the return email, returning an error message or null when valid.
String? validateContactEmail(String? value) {
  final email = value?.trim() ?? '';

  if (email.isEmpty) {
    return 'Enter your return email.';
  }

  if (!contactEmailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }

  return null;
}

/// Validates the question, returning an error message or null when valid.
String? validateContactQuestion(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Enter your question.';
  }

  if (value.trim().length < contactQuestionMinLength) {
    return 'The question must contain at least five characters.';
  }

  return null;
}

/// Combines app version and build number for artifact reporting.
///
/// Missing values collapse to `Unavailable` so the payload never sends blanks.
String formatArtifactVersion({String? version, String? buildNumber}) {
  final resolvedVersion = (version ?? '').trim();
  final resolvedBuild = (buildNumber ?? '').trim();

  if (resolvedVersion.isEmpty) {
    return 'Unavailable';
  }

  return resolvedBuild.isEmpty
      ? resolvedVersion
      : '$resolvedVersion (build $resolvedBuild)';
}

/// Classifies a viewport width into the label sent with a submission.
String contactLayoutName(double width) {
  if (width >= 1100) {
    return 'Desktop';
  }
  if (width >= 600) {
    return 'Tablet';
  }
  return 'Phone';
}
