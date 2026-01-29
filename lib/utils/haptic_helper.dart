import 'package:flutter/services.dart';

/// Helper class for consistent haptic feedback across the app
class HapticHelper {
  /// Light haptic feedback for subtle interactions
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium haptic feedback for standard interactions
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy haptic feedback for important actions
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback for picker/slider interactions
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate feedback for successful actions
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Vibrate feedback for error/warning actions
  static void error() {
    HapticFeedback.vibrate();
  }
}
