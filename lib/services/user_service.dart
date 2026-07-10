import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Map<String, dynamic> buildUserUpdateData({
    String? name,
    String? email,
  }) {
    final data = <String, dynamic>{};
    if (name != null && name.isNotEmpty) data['name'] = name;
    if (email != null && email.isNotEmpty) data['email'] = email;
    return data;
  }

  static Future<Map<String, dynamic>?> getUser({required String uid}) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  static Future<void> createOrUpdateUser({
    required String uid,
    required String phoneNumber,
    required String role,
    String name = 'User',
    String? email,
    String? roleDetail,
  }) async {
    final data = <String, dynamic>{
      'uid': uid,
      'phone': phoneNumber,
      'role': role,
      'name': name,
      'email': email,
      'isAuthenticated': true,
      'authProvider': 'otp-demo',
      'lastLoginAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (role.toLowerCase() == 'driver') {
      data['vehicleType'] = roleDetail ?? 'General';
    } else {
      data['travelPreference'] = roleDetail ?? 'General';
    }

    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  static Future<void> updateUser({
    required String uid,
    String? name,
    String? email,
  }) async {
    final data = buildUserUpdateData(name: name, email: email);
    if (data.isEmpty) return;
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
}
