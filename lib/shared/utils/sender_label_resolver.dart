/// Resolves a sender key ("kknair1967@ybl") to the user's label ("papa")
/// using one rule everywhere — income tab, activity cards, details sheets.
///
/// Order:
///   1. exact key match,
///   2. VPA local-part match (label set for "kk9396" matches "kk9396@okhdfcbank"),
///   3. stem match: a label set on "kknair9396@ybl" also names "kknair1967@ybl"
///      and "kknair1967@axl", because they share the distinctive stem "kknair".
///      PSP handles ("ybl", "axl", "okaxis"…) are never stems, so labels don't
///      leak across unrelated VPAs.
library;

/// VPA PSP handles and bank tags — never distinctive enough to be a stem.
const _pspHandles = {
  'axl', 'ybl', 'upi', 'ibl', 'paytm', 'phonepe', 'gpay', 'cred',
  'okaxis', 'okhdfcbank', 'okicici', 'okbank', 'okpnb', 'oksbi', 'oksib',
  'okyesbank', 'hdfcbank', 'icici', 'sbi', 'yesbank', 'axisbank', 'kotak',
  'pockets', 'amazonpay', 'hdfc', 'axis', 'ib',
  // Generic words that appear in bank narration — never distinctive.
  'bank', 'a/c', 'ac', 'via', 'to', 'from', 'ref',
};

/// The user label for [key], or null when the sender isn't named.
String? resolveSenderLabel(String key, Map<String, String> labels) {
  if (labels.isEmpty) return null;
  final normalized = key.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final direct = labels[normalized] ?? labels[normalized.split('@').first];
  if (direct != null) return direct;

  // Stem matching: longest distinctive stem first, so the most specific
  // label wins when several could match.
  final stems = <(String, String)>[];
  labels.forEach((labelKey, label) {
    final localPart = labelKey.split('@').first;
    for (final match in RegExp(r'[a-z]{4,}').allMatches(localPart)) {
      final stem = match.group(0)!;
      if (!_pspHandles.contains(stem)) stems.add((stem, label));
    }
    for (final match in RegExp(r'\d{7,}').allMatches(localPart)) {
      stems.add((match.group(0)!, label));
    }
  });
  stems.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  for (final (stem, label) in stems) {
    if (normalized.contains(stem)) return label;
  }
  return null;
}
