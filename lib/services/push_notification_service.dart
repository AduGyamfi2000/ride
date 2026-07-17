import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Client-side push notification plumbing: requests permission, retrieves
/// this device's FCM token, and lets a screen listen for messages that
/// arrive while the app is in the foreground.
///
/// ⚠️ THIS ONLY COVERS RECEIVING NOTIFICATIONS, NOT SENDING THEM ⚠️
/// Actually triggering one automatically — e.g. "notify this driver's
/// device the instant a matching ride request appears" — needs something
/// server-side to watch Firestore and call the FCM API. That's normally a
/// Cloud Function, and Cloud Functions require Firebase's paid Blaze plan
/// to enable at all (same requirement we hit with Firebase Storage
/// earlier, and the same reason a real backend for OTP verification isn't
/// built either — see the note in lib/auth/otp_generator.dart).
///
/// Until that exists, notifications can only be sent manually — Firebase
/// Console → Cloud Messaging → "Send test message", pasting in the token
/// this service saves to the driver's profile (`fcmToken` field via
/// UserService.updateFcmToken). That's enough to demo that the *receiving*
/// side genuinely works end-to-end, just not automatically.
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Requests notification permission and returns this device's FCM
  /// token, or null if permission was denied or something went wrong
  /// (e.g. not supported on this platform/browser).
  static Future<String?> initAndGetToken() async {
    try {
      await _messaging.requestPermission();
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push notification setup failed (this is fine to ignore in dev): $e');
      }
      return null;
    }
  }

  /// Call from a screen's initState to react to messages that arrive
  /// while the app is open and in the foreground. Returns the
  /// subscription so the caller can cancel it in dispose().
  static StreamSubscription<RemoteMessage> listenForegroundMessages(
    void Function(RemoteMessage) onMessage,
  ) {
    return FirebaseMessaging.onMessage.listen(onMessage);
  }
}
