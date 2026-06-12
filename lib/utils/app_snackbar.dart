import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_localizations_ext.dart';

/// Centralised SnackBar helpers used across the app.
///
/// Error bars include a copy icon so the full message can be captured
/// and sent for support. Text is kept small (12 sp) so long technical
/// strings fit without completely dominating the screen.
class AppSnackBar {
  AppSnackBar._();

  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 8),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white, height: 1.35),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _CopyButton(message: message),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: context.l10n.retry,
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.message});
  final String message;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          color: Colors.white70,
          size: 16,
        ),
      ),
    );
  }
}
