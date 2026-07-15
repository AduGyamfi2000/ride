/// Firebase Auth's email/password provider needs something shaped like an
/// email, but this app only collects phone numbers. Rather than rolling
/// our own password hashing (which would mean storing/checking password
/// hashes ourselves, with no backend to do it securely), we reuse
/// Firebase's own battle-tested email/password auth under the hood by
/// deriving a synthetic, never-shown "email" from the phone number.
///
/// This is purely an internal identifier — it's never displayed to the
/// user and doesn't need to be a real, reachable address.
String syntheticEmailForPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return 'p$digits@ridehome.local';
}
