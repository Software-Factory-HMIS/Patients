import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../models/otp_delivery_channel.dart';

/// Maps known English API / exception messages to localized strings.
class ApiMessageLocalizer {
  ApiMessageLocalizer._();

  static String localize(BuildContext context, String raw) {
    final l = AppLocalizations.of(context);
    var message = raw.trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }
    if (message.startsWith('Failed to send OTP: ')) {
      final inner = message.substring('Failed to send OTP: '.length);
      return l.failedSendOtp(localize(context, inner));
    }

    final lower = message.toLowerCase();

    final cooldown = RegExp(
      r'please wait (\d+) seconds',
      caseSensitive: false,
    ).firstMatch(message);
    if (cooldown != null) {
      final seconds = int.tryParse(cooldown.group(1) ?? '') ?? 0;
      return l.apiCooldown(seconds);
    }

    if (lower.contains('otp sent successfully via sms') ||
        lower.contains('otp sent via sms')) {
      return l.apiOtpSentSms;
    }
    if (lower.contains('otp sent successfully via whatsapp') ||
        lower.contains('otp sent via whatsapp')) {
      return l.apiOtpSentWhatsapp;
    }
    if (lower.contains('otp verified successfully') ||
        lower.contains('otp verified. you can proceed')) {
      return l.apiOtpVerified;
    }
    if (lower.contains('invalid otp') || lower.contains('invalid code')) {
      return l.apiInvalidOtp;
    }
    if (lower.contains('invalid cnic or password')) {
      return l.apiInvalidCnicPassword;
    }
    if (lower.contains('failed to request otp')) {
      return l.apiFailedRequestOtp;
    }
    if (lower.contains('failed to verify otp')) {
      return l.apiFailedVerifyOtp;
    }
    if (lower.contains('failed to lookup patient') || lower.contains('failed to load patient')) {
      return l.apiFailedLookupPatient;
    }
    if (lower.contains('failed to initialize api client')) {
      return l.apiFailedInitClient;
    }
    if (lower.contains('patient not found') || lower.contains('account not found')) {
      return l.apiPatientNotFound;
    }
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup')) {
      return l.apiNetworkError;
    }

    final accountOtp = RegExp(
      r'we found your account\. otp will be sent to (.+)\.',
      caseSensitive: false,
    ).firstMatch(message);
    if (accountOtp != null) {
      return l.apiAccountFoundOtp(accountOtp.group(1)!.trim());
    }

    return message.isEmpty ? l.apiUnknownError : message;
  }

  static String channelLabel(BuildContext context, OtpDeliveryChannel channel) {
    final l = AppLocalizations.of(context);
    return switch (channel) {
      OtpDeliveryChannel.sms => l.channelSms,
      OtpDeliveryChannel.whatsApp => l.channelWhatsApp,
    };
  }
}

/// Keeps phone numbers, CNIC, and OTP codes left-to-right in Urdu layout.
class LtrText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const LtrText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
