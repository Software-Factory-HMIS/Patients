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
    return SegmentedButton<OtpDeliveryChannel>(
      segments: const [
        ButtonSegment<OtpDeliveryChannel>(
          value: OtpDeliveryChannel.sms,
          label: Text('SMS'),
          icon: Icon(Icons.sms_outlined, size: 18),
        ),
        ButtonSegment<OtpDeliveryChannel>(
          value: OtpDeliveryChannel.whatsApp,
          label: Text('WhatsApp'),
          icon: Icon(Icons.chat_outlined, size: 18),
        ),
      ],
      selected: <OtpDeliveryChannel>{value},
      onSelectionChanged: (Set<OtpDeliveryChannel> next) {
        if (next.isEmpty) return;
        onChanged(next.first);
      },
      showSelectedIcon: false,
    );
  }
}
