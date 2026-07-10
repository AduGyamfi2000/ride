class OtpWebHelper {
  static Future<void> initializeRecaptcha(String phoneNumber) async {}

  static Future<dynamic> sendPhoneOtp(String phoneNumber) async {
    throw UnsupportedError('Web OTP is not available in this build.');
  }
}
