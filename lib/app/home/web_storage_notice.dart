import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Warns web users that study data lives in browser storage.
///
/// The notice can be dismissed for the current session; the app reseeds bundled
/// study content on the next start.
class WebStorageNotice extends StatefulWidget {
  const WebStorageNotice({super.key});

  @override
  State<WebStorageNotice> createState() => _WebStorageNoticeState();
}

class _WebStorageNoticeState extends State<WebStorageNotice> {
  bool _isVisible = kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Theme.of(context).colorScheme.error,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Web notice: study data and preferences use browser storage. '
                  'Clearing site data removes them; bundled study content is '
                  'loaded again when the app starts.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss notice',
                onPressed: () => setState(() => _isVisible = false),
                icon: const Icon(Icons.close),
                color: Theme.of(context).colorScheme.onError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
