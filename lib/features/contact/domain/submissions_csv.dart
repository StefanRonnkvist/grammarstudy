/// Parsing and filtering rules for the submissions CSV.
library;

/// Display schema for a submission record, in column order.
const List<String> submissionsHeaders = <String>[
  'Name',
  'eMail',
  'App',
  'Version',
  'Series',
  'Content',
  'Date Time',
];

/// Zero-based index of the column compared against the current package name.
const int submissionsAppColumnIndex = 2;

/// Parsed submissions, already filtered for one package.
class SubmissionsTable {
  const SubmissionsTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  bool get isEmpty => rows.isEmpty;
}

/// Parses comma-separated rows, honouring quoted commas, escaped quotes, and
/// both Unix and Windows line endings.
///
/// Blank rows are dropped. A trailing field is always emitted, so input ending
/// in a newline does not produce a spurious empty row.
List<List<String>> parseSubmissionsCsv(String input) {
  final rows = <List<String>>[];
  var currentRow = <String>[];
  final currentField = StringBuffer();
  var inQuotes = false;

  void endField() {
    currentRow.add(currentField.toString());
    currentField.clear();
  }

  void endRow() {
    endField();
    if (currentRow.any((value) => value.isNotEmpty)) {
      rows.add(List<String>.from(currentRow));
    }
    currentRow = <String>[];
  }

  var i = 0;
  while (i < input.length) {
    final char = input[i];

    if (char == '"') {
      // A doubled quote inside a quoted field is a literal quote.
      if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
        currentField.write('"');
        i += 2;
        continue;
      }

      inQuotes = !inQuotes;
      i += 1;
      continue;
    }

    if (!inQuotes && char == ',') {
      endField();
      i += 1;
      continue;
    }

    if (!inQuotes && (char == '\n' || char == '\r')) {
      endRow();
      // Treat CRLF as a single line break.
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i += 2;
      } else {
        i += 1;
      }
      continue;
    }

    currentField.write(char);
    i += 1;
  }

  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    endRow();
  }

  return rows;
}

/// Pads [rows] to the fixed display schema and keeps only rows whose App
/// column matches [currentApp], compared case-insensitively.
///
/// Rows longer than the schema are left intact rather than being truncated, so
/// extra columns never cause a negative-length padding error.
SubmissionsTable buildSubmissionsTable(
  List<List<String>> rows, {
  required String currentApp,
}) {
  if (rows.isEmpty) {
    return const SubmissionsTable(headers: [], rows: []);
  }

  final expectedLength = submissionsHeaders.length;
  final normalized = rows
      .map((row) {
        if (row.length >= expectedLength) {
          return List<String>.from(row, growable: false);
        }
        return <String>[
          ...row,
          ...List<String>.filled(expectedLength - row.length, ''),
        ];
      })
      .toList(growable: false);

  final normalizedApp = currentApp.trim().toLowerCase();
  final filtered = normalized
      .where((row) {
        final appValue = row[submissionsAppColumnIndex].trim().toLowerCase();
        return appValue == normalizedApp;
      })
      .toList(growable: false);

  return SubmissionsTable(
    headers: List<String>.from(submissionsHeaders, growable: false),
    rows: filtered,
  );
}
