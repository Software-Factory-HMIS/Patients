import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autoFocus;

  const OtpInput({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onCompleted,
    this.autoFocus = true,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _notify() {
    final v = _value;
    widget.onChanged?.call(v);
    final isComplete = _controllers.every((c) => c.text.trim().isNotEmpty) && v.length == widget.length;
    if (isComplete) {
      widget.onCompleted?.call(v);
    }
  }

  void _setAllFromPaste(String digits) {
    final clean = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;

    for (int i = 0; i < widget.length; i++) {
      _controllers[i].text = i < clean.length ? clean[i] : '';
    }

    final idx = (clean.length >= widget.length ? widget.length - 1 : clean.length - 1).clamp(0, widget.length - 1);
    _focusNodes[idx].requestFocus();
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 10),
          child: SizedBox(
            width: 56,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (_controllers[index].text.isEmpty && index > 0) {
                    _controllers[index - 1].text = '';
                    _focusNodes[index - 1].requestFocus();
                    _notify();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onChanged: (val) {
                  if (val.length > 1) {
                    _setAllFromPaste(val);
                    return;
                  }
                  if (val.isNotEmpty) {
                    if (index < widget.length - 1) {
                      _focusNodes[index + 1].requestFocus();
                    } else {
                      _focusNodes[index].unfocus();
                    }
                  }
                  _notify();
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}

