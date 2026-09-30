import 'package:flutter/material.dart';

/// Renders a centred progress indicator with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.detail});

  final String? message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Renders a failure message with a retry action.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a centred empty-state message.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}

/// Renders a labelled search field wired to [onChanged].
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Renders a numbered list row matching the study tab layouts.
class NumberedListTile extends StatelessWidget {
  const NumberedListTile({
    super.key,
    required this.index,
    required this.title,
    this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final int index;
  final String title;
  final VoidCallback? onTap;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leading ?? CircleAvatar(child: Text('${index + 1}')),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
    );
  }
}

/// Renders a numbered row whose title is a rich span, such as highlighted text.
class RichNumberedListTile extends StatelessWidget {
  const RichNumberedListTile({
    super.key,
    required this.number,
    required this.title,
    this.onTap,
  });

  final String number;
  final InlineSpan title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(radius: 14, child: Text(number)),
      title: Text.rich(title),
    );
  }
}
