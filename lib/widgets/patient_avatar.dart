import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/patient_photo_service.dart';

class PatientAvatar extends StatefulWidget {
  final int patientId;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;

  const PatientAvatar({
    super.key,
    required this.patientId,
    this.name,
    this.radius = 28,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  State<PatientAvatar> createState() => _PatientAvatarState();
}

class _PatientAvatarState extends State<PatientAvatar> {
  PatientPhotoData? _photo;

  @override
  void initState() {
    super.initState();
    _load();
    PatientPhotoService.instance.revision.addListener(_load);
  }

  @override
  void didUpdateWidget(covariant PatientAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) _load();
  }

  @override
  void dispose() {
    PatientPhotoService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final photo = await PatientPhotoService.instance.load(widget.patientId);
    if (!mounted) return;
    setState(() => _photo = photo);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.backgroundColor ?? scheme.primaryContainer;
    final fg = widget.foregroundColor ?? scheme.primary;
    final initial = (widget.name != null && widget.name!.isNotEmpty)
        ? widget.name!.trim()[0].toUpperCase()
        : 'P';

    ImageProvider? imageProvider;
    if (_photo?.bytes != null) {
      imageProvider = MemoryImage(_photo!.bytes!);
    } else if (!kIsWeb && _photo?.filePath != null) {
      imageProvider = FileImage(File(_photo!.filePath!));
    }

    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg,
      foregroundColor: fg,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: widget.radius * 0.9,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );

    if (widget.borderWidth > 0 && widget.borderColor != null) {
      return Container(
        padding: EdgeInsets.all(widget.borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.borderColor!,
            width: widget.borderWidth,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
