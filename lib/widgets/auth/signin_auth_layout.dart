import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../utils/app_localizations_ext.dart';
import '../../utils/brand_assets.dart';
import 'signin_auth_theme.dart';

/// Responsive sizing for sign-in flow screens.
class SignInMetrics {
  final bool isCompactWidth;
  final bool isShortHeight;
  final bool isVeryShortHeight;
  final double horizontalPadding;
  final double cardPadding;
  final double cardMaxWidth;
  final double titleFontSize;
  final double labelFontSize;
  final double inputHeight;
  final double buttonHeight;
  final double smallGap;
  final double mediumGap;
  final double largeGap;
  final double infoBoxPadding;
  final double iconSize;
  final double logoSize;
  final double headerTitleFontSize;

  const SignInMetrics({
    required this.isCompactWidth,
    required this.isShortHeight,
    required this.isVeryShortHeight,
    required this.horizontalPadding,
    required this.cardPadding,
    required this.cardMaxWidth,
    required this.titleFontSize,
    required this.labelFontSize,
    required this.inputHeight,
    required this.buttonHeight,
    required this.smallGap,
    required this.mediumGap,
    required this.largeGap,
    required this.infoBoxPadding,
    required this.iconSize,
    required this.logoSize,
    required this.headerTitleFontSize,
  });

  factory SignInMetrics.of(BuildContext context, BoxConstraints constraints) {
    final size = MediaQuery.sizeOf(context);
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : size.width;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : size.height;

    final isCompactWidth = width < 380;
    final isShortHeight = height < 740;
    final isVeryShortHeight = height < 650;

    return SignInMetrics(
      isCompactWidth: isCompactWidth,
      isShortHeight: isShortHeight,
      isVeryShortHeight: isVeryShortHeight,
      horizontalPadding: isCompactWidth ? 16 : 24,
      cardPadding: isVeryShortHeight
          ? 16
          : isShortHeight
          ? 18
          : 22,
      cardMaxWidth: 430,
      titleFontSize: isCompactWidth ? 15 : 16,
      labelFontSize: isCompactWidth ? 14 : 16,
      inputHeight: isVeryShortHeight ? 50 : 56,
      buttonHeight: isVeryShortHeight ? 48 : 54,
      smallGap: isVeryShortHeight
          ? 6
          : isShortHeight
          ? 8
          : 10,
      mediumGap: isVeryShortHeight
          ? 10
          : isShortHeight
          ? 12
          : 16,
      largeGap: isVeryShortHeight
          ? 14
          : isShortHeight
          ? 16
          : 22,
      infoBoxPadding: isVeryShortHeight
          ? 10
          : isShortHeight
          ? 12
          : 14,
      iconSize: isCompactWidth ? 20 : 22,
      logoSize: isVeryShortHeight
          ? 88
          : isShortHeight
          ? 100
          : 112,
      headerTitleFontSize: isVeryShortHeight
          ? 26
          : isShortHeight
          ? 30
          : 34,
    );
  }
}

/// Shared chrome for Punjab Patient App sign-in steps: header, footer, help links.
class SignInAuthLayout extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;

  const SignInAuthLayout({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SignInAuthTheme.pageDecorationFor(context),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = SignInMetrics.of(context, constraints);
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: metrics.horizontalPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: bodyConstraints.maxHeight,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (showBackButton)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      onPressed:
                                          onBack ??
                                          () => Navigator.maybePop(context),
                                      icon: Icon(
                                        Icons.arrow_back_rounded,
                                        color: SignInAuthTheme.bodyTextColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                SignInAuthHeader(metrics: metrics),
                                Gap(metrics.mediumGap),
                                SizedBox(
                                  width: double.infinity,
                                  child: child,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    metrics.horizontalPadding,
                    metrics.smallGap,
                    metrics.horizontalPadding,
                    metrics.mediumGap,
                  ),
                  child: const SignInAuthFooter(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SignInAuthHeader extends StatelessWidget {
  final SignInMetrics? metrics;

  const SignInAuthHeader({super.key, this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final logoSize = m?.logoSize ?? 112;
    final titleSize = m?.headerTitleFontSize ?? 34;
    final titleStyle = TextStyle(
      fontFamily: 'serif',
      fontSize: titleSize,
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: -0.5,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          BrandAssets.logo,
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.health_and_safety_rounded,
            size: logoSize * 0.85,
            color: SignInAuthTheme.primary,
          ),
        ),
        const Gap(10),
        Text.rich(
          TextSpan(
            style: titleStyle,
            children: const [
              TextSpan(
                text: 'My Health ',
                style: TextStyle(color: SignInAuthTheme.titleGreen),
              ),
              TextSpan(
                text: 'Record',
                style: TextStyle(color: SignInAuthTheme.brandLink),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(4),
        Text(
          context.l10n.governmentOfPunjab,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: SignInAuthTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class SignInAuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SignInAuthCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: SignInAuthTheme.cardDecorationFor(context),
      child: child,
    );
  }
}

class SignInContinueButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final bool loading;
  final double? height;

  const SignInContinueButton({
    super.key,
    this.label,
    this.onPressed,
    this.loading = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? context.l10n.continueButton;
    final buttonHeight = height ?? 54;
    final compact = buttonHeight < 54;

    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SignInAuthTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SignInAuthTheme.primary.withValues(
            alpha: 0.5,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Gap(10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: compact ? 20 : 22,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}

class SignInInfoBox extends StatelessWidget {
  final String message;
  final bool compact;

  const SignInInfoBox({super.key, required this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: SignInAuthTheme.infoBoxDecorationFor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 20 : 22,
            height: compact ? 20 : 22,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: compact ? 12 : 14,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Gap(compact ? 10 : 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                height: 1.45,
                color: SignInAuthTheme.bodyTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignInHospitalSupportButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  const SignInHospitalSupportButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Tooltip(
      message: l.visitNearestHospitalSupport,
      preferBelow: true,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: SignInAuthTheme.bodyTextColor(context),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 12 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        icon: loading
            ? SizedBox(
                width: compact ? 18 : 20,
                height: compact ? 18 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SignInAuthTheme.mutedTextColor(context),
                ),
              )
            : Icon(
                Icons.local_hospital_outlined,
                size: compact ? 18 : 20,
                color: SignInAuthTheme.primary,
              ),
        label: Text(
          l.hospitalSupport,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SignInAuthFooter extends StatelessWidget {
  const SignInAuthFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          BrandAssets.punjabCrest,
          width: 64,
          height: 52,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: l.governmentOfPunjab,
        ),
        const Gap(6),
        Text(
          l.healthcarePortalFooter,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            color: SignInAuthTheme.textMuted,
          ),
        ),
        const Gap(4),
        Text(
          l.copyrightPitb,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: SignInAuthTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
