import 'package:flutter/material.dart';

class KeyboardInsetPadding extends StatelessWidget {
  final Widget child;
  
  const KeyboardInsetPadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: child,
    );
  }
}
