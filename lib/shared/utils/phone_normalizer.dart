/// Phone-number helpers shared by contact matching and sender identity.

/// Strips everything non-digit from [raw] and returns the last 10 digits —
/// the canonical form for matching Indian mobile numbers. Returns null when
/// there aren't enough digits to be a phone number.
String? lastTenDigits(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return null;
  return digits.substring(digits.length - 10);
}

/// Every plausible 10-digit phone number in [raw], most specific first.
///
/// A sender key can bury a phone number in a VPA: "9855343141-2@ybl" contains
/// an 11-digit run where the real number is the first 10 digits, while a plain
/// "8075637374" is exactly 10. Contact matching should try all candidates —
/// the last 10 digits, the first 10, and every 10-digit window — so a number
/// with a suffix (like a UPI account index) still matches the contact book.
List<String> phoneCandidates(String? raw) {
  if (raw == null) return const [];
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return const [];

  final candidates = <String>{};
  // Full 10-digit runs and sliding windows.
  for (var i = 0; i + 10 <= digits.length; i++) {
    candidates.add(digits.substring(i, i + 10));
  }
  // If the run is longer than 10 digits, the real number is usually at the
  // start (country-code stripped) or the end.
  if (digits.length > 10) {
    candidates.add(digits.substring(digits.length - 10));
    candidates.add(digits.substring(0, 10));
  }
  return candidates.toList();
}
