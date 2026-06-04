/// Values sent as JSON `channel` on patient-auth OTP endpoints (matches HMIS API).
enum OtpDeliveryChannel {
  sms,
  whatsApp;

  /// API body value: `sms` or `whatsapp`.
  String get apiValue => switch (this) {
        OtpDeliveryChannel.whatsApp => 'whatsapp',
        OtpDeliveryChannel.sms => 'sms',
      };

  String get label => switch (this) {
        OtpDeliveryChannel.whatsApp => 'WhatsApp',
        OtpDeliveryChannel.sms => 'SMS',
      };
}
