import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../utils/app_localizations_ext.dart';
import '../utils/brand_assets.dart';

/// Government of Punjab Health Department design tokens.
class PunjabColors {
  PunjabColors._();

  static const primary = Color(0xFF1B5E3B);
  static const primaryDark = Color(0xFF0F3D24);
  static const primaryLight = Color(0xFF2E7D4F);
  static const accent = Color(0xFF3D9970);
  static const background = Color(0xFFF4F6F4);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF1A1F1C);
  static const textSecondary = Color(0xFF5C6760);
  static const border = Color(0xFFE2E8E4);
  static const success = Color(0xFF2E7D4F);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const labBlue = Color(0xFF2563EB);
  static const radPurple = Color(0xFF7C3AED);
  static const rxGreen = Color(0xFF059669);
  static const visitOrange = Color(0xFFEA580C);
}

/// Compact app branding for the home screen (logo + title).
class PunjabAppBrandRow extends StatelessWidget {
  const PunjabAppBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark
        ? Theme.of(context).colorScheme.onSurface
        : PunjabColors.primaryDark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            BrandAssets.logo,
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.health_and_safety_rounded,
              size: 40,
              color: PunjabColors.primary,
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Text(
            context.l10n.appNameShort,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.2,
              color: titleColor,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class PunjabLogoHeader extends StatelessWidget {
  final String? stepLabel;
  final bool compact;

  const PunjabLogoHeader({super.key, this.stepLabel, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.0 : 96.0;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            BrandAssets.logo,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.health_and_safety_rounded,
              size: size * 0.5,
              color: PunjabColors.primary,
            ),
          ),
        ),
        const Gap(12),
        Text(
          context.l10n.appNameShort,
          style: TextStyle(
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w800,
            color: PunjabColors.primaryDark,
          ),
        ),
        Text(
          context.l10n.healthDepartment,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            height: 1.35,
            color: PunjabColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (stepLabel != null) ...[
          const Gap(14),
          PunjabStepBadge(label: stepLabel!),
        ],
      ],
    );
  }
}

class PunjabStepBadge extends StatelessWidget {
  final String label;
  const PunjabStepBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: PunjabColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PunjabColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PunjabColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class PunjabCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const PunjabCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final fill = theme.cardTheme.color ?? scheme.surfaceContainerHighest;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              borderColor ??
              scheme.outline.withValues(alpha: dark ? 0.45 : 0.8),
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Standard page title for main [PatientShell] tab screens.
class PunjabPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Consistent horizontal and top inset below the shell [SafeArea].
  static const EdgeInsets screenInsets = EdgeInsets.fromLTRB(16, 12, 16, 0);

  const PunjabPageHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark
        ? Theme.of(context).colorScheme.onSurface
        : PunjabColors.primaryDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.3,
            color: titleColor,
          ),
        ),
        if (subtitle != null) ...[
          const Gap(4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: PunjabColors.textSecondary,
            ),
          ),
        ],
        const Gap(16),
      ],
    );
  }
}

class PunjabSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const PunjabSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class PunjabPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PunjabPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: loading ? () {} : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: PunjabColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: loading
              ? PunjabColors.primary
              : const Color(0xFFE3EAE5),
          disabledForegroundColor: loading
              ? Colors.white
              : const Color(0xFF8A968F),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label),
                  if (icon != null) ...[const Gap(8), Icon(icon, size: 20)],
                ],
              ),
      ),
    );
  }
}

class PunjabBookingStepper extends StatelessWidget {
  final int currentStep;

  const PunjabBookingStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [l.stepHospital, l.stepDepartment, l.stepConfirm];
    final compact = MediaQuery.sizeOf(context).width < 380;
    final circleSize = compact ? 30.0 : 32.0;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIndex < currentStep
                  ? PunjabColors.primary
                  : PunjabColors.border,
            ),
          );
        }
        final step = i ~/ 2;
        final completed = step < currentStep;
        final current = step == currentStep;
        final active = completed || current;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: active ? PunjabColors.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? PunjabColors.primary : PunjabColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: completed
                      ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: compact ? 14 : 16,
                        )
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            color: current
                                ? Colors.white
                                : PunjabColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 13 : 14,
                          ),
                        ),
                ),
              ),
              const Gap(4),
              Text(
                steps[step],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  color: active
                      ? PunjabColors.primary
                      : PunjabColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Tab indices for [PunjabBottomNav] (Home is centered at index 2).
abstract final class PatientTabIndex {
  static const book = 0;
  static const visits = 1;
  static const home = 2;
  static const health = 3;
  static const profile = 4;
}

class PunjabBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PunjabBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const bubbleSize = 48.0;
  static const horizontalInset = 16.0;
  static const notchRadius = bubbleSize / 2 + 4;
  static const barTopY = 32.0;
  static const barBodyHeight = 60.0;
  static const navBarHeight = barTopY + barBodyHeight;
  static const cornerRadius = 26.0;
  static const bubbleRise = bubbleSize / 2 + 6;
  static const overlayHeight = navBarHeight + bubbleRise;

  /// Bottom inset for scrollable tab pages under [PatientShell] with `extendBody: true`.
  ///
  /// Matches nav footprint: [overlayHeight] + SafeArea bottom + outer padding (8).
  static double contentBottomPadding(BuildContext context) {
    return overlayHeight +
        MediaQuery.paddingOf(context).bottom +
        8 + // PunjabBottomNav outer bottom padding
        32; // clearance for primary buttons above the floating bubble
  }

  /// Short dashboard pages (home) — avoids a large empty strip above the nav bar.
  static double homeBottomPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 8;
  }

  static const itemCount = 5;

  static List<(IconData, String)> items(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      (Icons.event_available_rounded, l.tabBookVisit),
      (Icons.assignment_rounded, l.tabMyVisits),
      (Icons.home_rounded, l.tabHome),
      (Icons.favorite_rounded, l.tabHealth),
      (Icons.person_rounded, l.tabProfile),
    ];
  }

  @override
  State<PunjabBottomNav> createState() => _PunjabBottomNavState();
}

class _PunjabBottomNavState extends State<PunjabBottomNav>
    with SingleTickerProviderStateMixin {
  static const _bubbleSize = PunjabBottomNav.bubbleSize;
  static const _horizontalInset = PunjabBottomNav.horizontalInset;
  static const _notchRadius = PunjabBottomNav.notchRadius;
  static const _barTopY = PunjabBottomNav.barTopY;
  static const _navHeight = PunjabBottomNav.navBarHeight;
  static const _cornerRadius = PunjabBottomNav.cornerRadius;
  static const _bubbleRise = PunjabBottomNav.bubbleRise;

  late final AnimationController _fluidController;
  late Animation<double> _centerAnimation;
  late Animation<double> _bubbleScaleAnimation;
  late Animation<double> _bubbleLiftAnimation;

  double _centerX = 0;
  double _barWidth = 0;
  bool _laidOut = false;
  TextDirection? _lastTextDirection;

  @override
  void initState() {
    super.initState();
    _fluidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _centerAnimation = const AlwaysStoppedAnimation(0);
    _bubbleScaleAnimation = const AlwaysStoppedAnimation(1);
    _bubbleLiftAnimation = const AlwaysStoppedAnimation(0);
    _fluidController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant PunjabBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && _laidOut) {
      _animateToIndex(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _fluidController.dispose();
    super.dispose();
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  /// Visual center X for tab [index], accounting for RTL row reversal.
  double _centerForIndex(int index) {
    final itemWidth = _barWidth / PunjabBottomNav.itemCount;
    final ltr = itemWidth * index + itemWidth / 2;
    return _isRtl ? _barWidth - ltr : ltr;
  }

  /// Keeps the bubble inside the bar without pulling edge tabs far from their slot center.
  double _safeBubbleCenterFor(double centerX) {
    final sidePadding = _bubbleSize / 2 + 4;
    final minCx = sidePadding;
    final maxCx = math.max(minCx, _barWidth - sidePadding);
    return centerX.clamp(minCx, maxCx).toDouble();
  }

  void _configureAnimations({required double from, required double to}) {
    final slide = CurvedAnimation(
      parent: _fluidController,
      curve: Curves.easeInOutCubic,
    );
    _centerAnimation = Tween<double>(begin: from, end: to).animate(slide);
    final bubbleCurve = CurvedAnimation(
      parent: _fluidController,
      curve: Curves.easeInOutSine,
    );
    _bubbleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 42),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 58),
    ]).animate(bubbleCurve);
    _bubbleLiftAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 55),
    ]).animate(bubbleCurve);
  }

  void _animateToIndex(int index) {
    final from = _fluidController.isAnimating
        ? _centerAnimation.value
        : _centerX;
    final to = _centerForIndex(index);
    _configureAnimations(from: from, to: to);
    _fluidController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _centerX = to;
    });
  }

  void _ensureLayout(double width) {
    final dir = Directionality.of(context);
    final directionChanged = _laidOut && _lastTextDirection != dir;
    if (_laidOut && width == _barWidth && !directionChanged) return;

    _barWidth = width;
    _lastTextDirection = dir;
    final target = _centerForIndex(widget.currentIndex);
    if (!_laidOut) {
      _centerX = target;
      _centerAnimation = AlwaysStoppedAnimation(target);
      _laidOut = true;
    } else if (!_fluidController.isAnimating || directionChanged) {
      _centerX = target;
      _centerAnimation = AlwaysStoppedAnimation(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final barColor = dark ? const Color(0xFF1A2420) : Colors.white;
    final borderColor = dark
        ? scheme.outline.withValues(alpha: 0.55)
        : PunjabColors.primary.withValues(alpha: 0.38);
    final inactiveColor = scheme.onSurfaceVariant;
    final navItems = PunjabBottomNav.items(context);
    final activeIcon = navItems[widget.currentIndex].$1;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _horizontalInset,
            0,
            _horizontalInset,
            8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _ensureLayout(constraints.maxWidth);

              final tabCenterX = _centerAnimation.value;
              final visualCenterX = _safeBubbleCenterFor(tabCenterX);

              final itemWidth = _barWidth / PunjabBottomNav.itemCount;
              final pillWidth = math.max(0.0, itemWidth - 16);
              final pillLeft = visualCenterX - pillWidth / 2;

              final bubbleScale = _bubbleScaleAnimation.value;
              final bubbleLift = _bubbleLiftAnimation.value;
              final bubbleBottom =
                  _navHeight - _barTopY - _bubbleSize / 2 + bubbleLift;

              return SizedBox(
                height: _navHeight + _bubbleRise,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _navHeight,
                      child: CustomPaint(
                        painter: _FluidNavBarPainter(
                          centerX: visualCenterX,
                          barColor: barColor,
                          borderColor: borderColor,
                          notchRadius: _notchRadius,
                          barTopY: _barTopY,
                          cornerRadius: _cornerRadius,
                          shadowColor: Colors.black.withValues(
                            alpha: dark ? 0.22 : 0.08,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: pillLeft,
                              width: pillWidth,
                              bottom: 6,
                              height: 22,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: PunjabColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(navItems.length, (i) {
                                  final (icon, label) = navItems[i];
                                  final selected = i == widget.currentIndex;
                                  return Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => widget.onTap(i),
                                        borderRadius: BorderRadius.circular(20),
                                        child: SizedBox(
                                          height: _navHeight - 8,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              if (!selected) ...[
                                                const Spacer(),
                                                Icon(
                                                  icon,
                                                  size: 22,
                                                  color: inactiveColor,
                                                ),
                                                const Gap(4),
                                              ] else
                                                const Spacer(),
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: selected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: selected
                                                      ? PunjabColors.primary
                                                      : inactiveColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: visualCenterX - _bubbleSize / 2,
                      bottom: bubbleBottom,
                      child: Transform.scale(
                        scale: bubbleScale,
                        child: Container(
                          width: _bubbleSize,
                          height: _bubbleSize,
                          decoration: BoxDecoration(
                            color: PunjabColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: barColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: PunjabColors.primary.withValues(
                                  alpha: 0.38,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            activeIcon,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FluidNavBarPainter extends CustomPainter {
  final double centerX;
  final Color barColor;
  final Color borderColor;
  final Color shadowColor;
  final double notchRadius;
  final double barTopY;
  final double cornerRadius;

  const _FluidNavBarPainter({
    required this.centerX,
    required this.barColor,
    required this.borderColor,
    required this.shadowColor,
    required this.notchRadius,
    required this.barTopY,
    required this.cornerRadius,
  });

  Path _buildShapePath(Size size) {
    final w = size.width;
    final h = size.height;
    final topY = barTopY;

    final barRect = Rect.fromLTWH(0, topY, w, h - topY);
    final basePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(barRect, Radius.circular(cornerRadius)),
      );

    // Clamp only enough to keep the notch circle inside the bar — not cornerRadius + notchRadius.
    final safeCx = centerX
        .clamp(notchRadius, math.max(notchRadius, w - notchRadius))
        .toDouble();

    final notchPath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(safeCx, topY), radius: notchRadius),
      );

    return Path.combine(PathOperation.difference, basePath, notchPath);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shapePath = _buildShapePath(size);

    final fillPaint = Paint()
      ..color = barColor
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawShadow(shapePath, shadowColor, 10, false);
    canvas.drawPath(shapePath, fillPaint);
    canvas.drawPath(shapePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FluidNavBarPainter oldDelegate) {
    return (oldDelegate.centerX - centerX).abs() > 0.5 ||
        oldDelegate.barColor != barColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class PunjabStatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const PunjabStatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: PunjabCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Gap(4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PunjabQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const PunjabQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const Gap(8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class PunjabStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const PunjabStatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class PunjabOtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;

  const PunjabOtpBoxes({super.key, required this.controller, this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = (constraints.maxWidth - 5 * 8) / 6;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final char = i < controller.text.length ? controller.text[i] : '';
              final focused = i == controller.text.length;
              return Container(
                width: boxWidth.clamp(40, 52),
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: focused ? PunjabColors.primary : PunjabColors.border,
                    width: focused ? 2 : 1,
                  ),
                ),
                child: Text(
                  char,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PunjabColors.textPrimary,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class PunjabDeliveryOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PunjabDeliveryOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? PunjabColors.primary
                      : PunjabColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
