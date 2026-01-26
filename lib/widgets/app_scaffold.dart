import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget child;
  final bool useSafeArea;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.useSafeArea = true,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;

    Widget body = Container(
      color: bg,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (scrollable) {
      body = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: body,
      );
    }

    if (useSafeArea) body = SafeArea(child: body);

    return Scaffold(
      appBar: appBar,
      body: body,
    );
  }
}
