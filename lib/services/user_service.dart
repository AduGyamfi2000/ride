import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/api_keys.dart';
import '../models/user_profile_model.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Uploads a driver's license or car photo and returns its public URL.
  ///
  /// Uses Cloudinary's "unsigned upload" endpoint instead of Firebase
  /// Storage — Firebase now requires the paid Blaze plan just to enable
  /// Cloud Storage, whereas Cloudinary's free tier (25GB storage/bandwidth)
  /// needs no billing setup at all. Firestore itself is unaffected; this
  /// only changes where the *image files* live — the URL Cloudinary
  /// returns is what still gets stored in the Firestore user document
  /// (licenseImageUrl/carImageUrl), same as before.
  ///
  /// Before this works you need a free Cloudinary account with an
  /// "unsigned" upload preset — see CHANGES.md for the exact steps — and
  /// to fill in ApiKeys.cloudinaryCloudName / cloudinaryUploadPreset.
  static Future<String> uploadDriverDocument({
    required String phone,
    required File file,
    required String label, // 'license' or 'car'
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${ApiKeys.cloudinaryCloudName}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = ApiKeys.cloudinaryUploadPreset
      // Overwrites any previous photo for this driver/label combo instead
      // of accumulating a new file on every re-upload.
      ..fields['public_id'] = 'driver_documents/${_docIdFor(phone)}_$label'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Image upload failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }
}
