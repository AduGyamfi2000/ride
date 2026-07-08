import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createOrUpdateUser({
    required String uid,
    required String phoneNumber,
    required String role,
    String name = 'User',
    String? email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'phone': phoneNumber,
      'role': role,
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateUser({
    required String uid,
    String? name,
    String? email,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (data.isEmpty) return;
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
}
