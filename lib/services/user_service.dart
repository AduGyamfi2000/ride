import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile_model.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static String _docIdFor(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Creates or overwrites a user's profile, keyed by phone number so it
  /// survives reinstalls (see the note in otp_generator.dart about why
  /// this app doesn't key profiles by Firebase Auth uid).
  static Future<void> createOrUpdateUser(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(_docIdFor(profile.phone))
        .set(profile.toJson(), SetOptions(merge: true));
  }

  static Future<UserProfile?> fetchByPhone(String phone) async {
    final doc = await _firestore.collection('users').doc(_docIdFor(phone)).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(doc.data()!);
  }

  /// Uploads a driver's license or car photo to Firebase Storage and
  /// returns its download URL.
  static Future<String> uploadDriverDocument({
    required String phone,
    required File file,
    required String label, // 'license' or 'car'
  }) async {
    final ref = _storage.ref().child('driver_documents/${_docIdFor(phone)}/$label.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
