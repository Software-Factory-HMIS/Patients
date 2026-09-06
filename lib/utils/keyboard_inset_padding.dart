import 'package:flutter/material.dart';

/// Previously padded for keyboard insets. Kept as a pass-through so the
/// keyboard overlays the UI instead of resizing layouts.
class KeyboardInsetPadding extends StatelessWidget {
  final Widget child;

  const KeyboardInsetPadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
