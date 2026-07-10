// import 'dart:js_interop';
// import 'package:js/js.dart';

class OtpWebHelper {
  static Future<void> initializeRecaptcha(String phoneNumber, dynamic js) async {
    js.context.callMethod('eval', [
      """
      window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('submit-button', {
        'size': 'invisible',
        'callback': function(response) {
          console.log('Recaptcha resolved, sending OTP...');
        }
      });
      """
    ]);
  }

  static Future<dynamic> sendPhoneOtp(String phoneNumber) async {
    return phoneNumber;
  }
}
