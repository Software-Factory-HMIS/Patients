import 'package:flutter/material.dart';
import '../models/otp_delivery_channel.dart';

/// SMS vs WhatsApp — server must deliver OTP via the selected channel.
class OtpDeliverySelector extends StatelessWidget {
  final OtpDeliveryChannel value;
  final ValueChanged<OtpDeliveryChannel> onChanged;

  const OtpDeliverySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!whatsappOtpEnabled) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<OtpDeliveryChannel>(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        segments: const [
          ButtonSegment<OtpDeliveryChannel>(
            value: OtpDeliveryChannel.sms,
            label: Text('Text Message'),
            icon: Icon(Icons.sms_outlined, size: 22),
          ),
          ButtonSegment<OtpDeliveryChannel>(
            value: OtpDeliveryChannel.whatsApp,
            label: Text('WhatsApp'),
            icon: Icon(Icons.chat_outlined, size: 22),
          ),
        ],
        selected: <OtpDeliveryChannel>{value},
        onSelectionChanged: (Set<OtpDeliveryChannel> next) {
          if (next.isEmpty) return;
          onChanged(next.first);
        },
        showSelectedIcon: false,
      ),
    );
  }
}
