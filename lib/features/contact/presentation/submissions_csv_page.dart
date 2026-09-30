import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/submissions_csv.dart';

/// Hosts the submissions list as a full scaffold when used as a page.
class SubmissionsCsvPage extends StatefulWidget {
  const SubmissionsCsvPage({
    super.key,
    this.csvUrl = 'https://stefanronnkvist.com/submissions.csv',
    this.showAppBar = true,
  });

  final String csvUrl;
  final bool showAppBar;

  @override
  State<SubmissionsCsvPage> createState() => _SubmissionsCsvPageState();
}

class _SubmissionsCsvPageState extends State<SubmissionsCsvPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Submissions CSV'))
          : null,
      body: SubmissionsCsvCardsView(csvUrl: widget.csvUrl),
    );
  }
}

/// Downloads submissions and renders only records belonging to this package.
class SubmissionsCsvCardsView extends StatefulWidget {
  const SubmissionsCsvCardsView({
    super.key,
    this.csvUrl = 'https://stefanronnkvist.com/submissions.csv',
  });

  final String csvUrl;

  @override
  State<SubmissionsCsvCardsView> createState() =>
      _SubmissionsCsvCardsViewState();
}

class _SubmissionsCsvCardsViewState extends State<SubmissionsCsvCardsView> {
  static const double _titleFontSize = 15;
  static const double _fieldFontSize = 13.5;
  static const int _visibleFieldStartIndex = 2;

  late Future<SubmissionsTable> _tableFuture;

  @override
  void initState() {
    super.initState();
    _tableFuture = _loadCsv();
  }

  /// Downloads and filters the CSV for the running application.
  ///
  /// Parsing and filtering live in `domain/submissions_csv.dart` so they can be
  /// tested without a network request.
  Future<SubmissionsTable> _loadCsv() async {
    final uri = Uri.parse(widget.csvUrl);
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server returned status ${response.statusCode}.');
    }

    final csvText = utf8.decode(response.bodyBytes);
    final rows = parseSubmissionsCsv(csvText);

    if (rows.isEmpty) {
      return const SubmissionsTable(headers: [], rows: []);
    }

    final packageInfo = await PackageInfo.fromPlatform();

    return buildSubmissionsTable(
      rows,
      currentApp: packageInfo.packageName,
    );
  }

  Widget _buildNoInformationMessage() {
    return const Center(child: Text('No inquiries avalible'));
  }

  Widget _buildSubmissionCard({
    required int index,
    required List<String> headers,
    required List<String> row,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Submission #$index',
              style: TextStyle(
                fontSize: _titleFontSize,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ...List<Widget>.generate(headers.length - _visibleFieldStartIndex, (
              int offset,
            ) {
              final int fieldIndex = _visibleFieldStartIndex + offset;
              final String value = fieldIndex < row.length
                  ? row[fieldIndex]
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFieldRow(headers[fieldIndex], value),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: _fieldFontSize,
          color: colorScheme.onSurface,
        ),
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: _fieldFontSize,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          TextSpan(text: value.isEmpty ? '-' : value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubmissionsTable>(
      future: _tableFuture,
      builder: (BuildContext context, AsyncSnapshot<SubmissionsTable> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildNoInformationMessage();
        }

        final table = snapshot.data;

        if (table == null || table.isEmpty) {
          return _buildNoInformationMessage();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List<Widget>.generate(table.rows.length, (int index) {
              final List<String> row = table.rows[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == table.rows.length - 1 ? 0 : 10,
                ),
                child: _buildSubmissionCard(
                  index: index + 1,
                  headers: table.headers,
                  row: row,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
