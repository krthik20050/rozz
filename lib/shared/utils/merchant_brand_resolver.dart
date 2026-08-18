import 'package:flutter/material.dart';

/// Display identity for a transaction (icon + colors + normalized category).
///
/// Category names are deliberately single-word and match Gemini's vocabulary
/// ("Food", "Transport", ...) so cards and insights group transactions the same
/// way. [categoryOf] is the single source of truth for the fallback category —
/// use it anywhere a category must be derived without Gemini.
class MerchantBrand {
  final String name;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String category;

  const MerchantBrand({
    required this.name,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.category,
  });
}

class MerchantBrandResolver {
  /// Single-word category for a transaction, derived from merchant name.
  /// Mirrors Gemini's vocabulary so both sources group identically.
  static String categoryOf(String rawTitle, String? labelType, String direction) {
    final lower = rawTitle.toLowerCase();

    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('eats')) {
      return 'Food';
    }
    if (lower.contains('uber') || lower.contains('ola') || lower.contains('rapido')) {
      return 'Transport';
    }
    if (lower.contains('spotify')) {
      return 'Entertainment';
    }
    if (lower.contains('amazon')) {
      return 'Shopping';
    }
    if (lower.contains('irctc') || lower.contains('rail') || lower.contains('flight')) {
      return 'Travel';
    }
    if (lower.contains('netflix')) {
      return 'Subscriptions';
    }
    if (_isRecharge(lower)) {
      return 'Recharge';
    }
    if (_isInsurance(lower)) {
      return 'Insurance';
    }
    if (direction == 'credit' || lower.contains('salary') || lower.contains('deposit')) {
      return 'Income';
    }

    switch (labelType) {
      case 'atm':
        return 'ATM';
      case 'upi':
        // UPI is a payment mode, not a spending category — lumping every
        // unknown UPI debit under "UPI" makes it the "biggest expense"
        // no matter what. Use a real bucket instead.
        return 'Transfers';
      default:
        return 'Bank';
    }
  }

  static bool _isRecharge(String lower) {
    return lower.contains('jio') ||
        lower.contains('airtel') ||
        lower.contains('vi ') ||
        lower.contains('vodafone') ||
        lower.contains('bsnl') ||
        lower.contains('recharge') ||
        lower.contains('prepaid');
  }

  static bool _isInsurance(String lower) {
    return lower.contains('lic') ||
        lower.contains('insurance') ||
        lower.contains('bajaj allianz') ||
        lower.contains('hdfc ergo') ||
        lower.contains('icici lombard') ||
        lower.contains('tata aig') ||
        lower.contains('sbi life') ||
        lower.contains('hdfc life') ||
        lower.contains('max life') ||
        lower.contains('policybazaar') ||
        lower.contains('digit');
  }

  static String _insuranceName(String lower) {
    if (lower.contains('lic')) return 'LIC';
    if (lower.contains('bajaj allianz')) return 'Bajaj Allianz';
    if (lower.contains('hdfc ergo')) return 'HDFC Ergo';
    if (lower.contains('icici lombard')) return 'ICICI Lombard';
    if (lower.contains('tata aig')) return 'Tata AIG';
    if (lower.contains('sbi life')) return 'SBI Life';
    if (lower.contains('hdfc life')) return 'HDFC Life';
    if (lower.contains('max life')) return 'Max Life';
    if (lower.contains('policybazaar')) return 'PolicyBazaar';
    return 'Insurance';
  }

  /// Try to extract a merchant name from raw SMS text when recipientName is empty.
  static String _extractFromRawSms(String rawSms) {
    if (rawSms.isEmpty) return '';
    // Common patterns: "to SWIGGY via UPI", "to JOHN DOE on", "Payment of Rs.100 to SWIGGY"
    final toMatch = RegExp(r'\bto\s+([A-Z][A-Z0-9& .\/\-]+?)(?:\s+via|\s+on|\s+Ref|\s*$)', caseSensitive: false).firstMatch(rawSms);
    if (toMatch != null) return toMatch.group(1)?.trim() ?? '';
    // "from JOHN DOE"
    final fromMatch = RegExp(r'\bfrom\s+([A-Z][A-Z0-9& .\/\-]+?)(?:\s+via|\s+on|\s+Ref|\s*$)', caseSensitive: false).firstMatch(rawSms);
    if (fromMatch != null) return fromMatch.group(1)?.trim() ?? '';
    return '';
  }

  static MerchantBrand resolve(String rawTitle, String? labelType, String direction, {String rawSms = ''}) {
    // Use rawTitle if available, otherwise try to extract from rawSms
    final effectiveTitle = rawTitle.isNotEmpty ? rawTitle : _extractFromRawSms(rawSms);
    final lower = effectiveTitle.toLowerCase();

    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('eats')) {
      return const MerchantBrand(
        name: 'Swiggy',
        icon: Icons.fastfood_rounded,
        backgroundColor: Color(0xFFFC6011),
        iconColor: Colors.white,
        category: 'Food',
      );
    }
    if (lower.contains('uber') || lower.contains('ola') || lower.contains('rapido')) {
      return const MerchantBrand(
        name: 'Uber',
        icon: Icons.directions_car_rounded,
        backgroundColor: Color(0xFF111111),
        iconColor: Colors.white,
        category: 'Transport',
      );
    }
    if (lower.contains('spotify')) {
      return const MerchantBrand(
        name: 'Spotify',
        icon: Icons.music_note_rounded,
        backgroundColor: Color(0xFF1DB954),
        iconColor: Colors.black,
        category: 'Entertainment',
      );
    }
    if (lower.contains('amazon')) {
      return const MerchantBrand(
        name: 'Amazon',
        icon: Icons.shopping_bag_rounded,
        backgroundColor: Color(0xFF232F3E),
        iconColor: Color(0xFFFF9900),
        category: 'Shopping',
      );
    }
    if (lower.contains('irctc') || lower.contains('rail') || lower.contains('flight')) {
      return const MerchantBrand(
        name: 'IRCTC',
        icon: Icons.train_rounded,
        backgroundColor: Color(0xFF5B2C6F),
        iconColor: Colors.white,
        category: 'Travel',
      );
    }
    if (lower.contains('netflix')) {
      return const MerchantBrand(
        name: 'Netflix',
        icon: Icons.tv_rounded,
        backgroundColor: Color(0xFFE50914),
        iconColor: Colors.white,
        category: 'Subscriptions',
      );
    }
    if (lower.contains('jio')) {
      return const MerchantBrand(
        name: 'Jio',
        icon: Icons.signal_cellular_alt_rounded,
        backgroundColor: Color(0xFF0A2885),
        iconColor: Colors.white,
        category: 'Recharge',
      );
    }
    if (lower.contains('airtel')) {
      return const MerchantBrand(
        name: 'Airtel',
        icon: Icons.phone_android_rounded,
        backgroundColor: Color(0xFFE40000),
        iconColor: Colors.white,
        category: 'Recharge',
      );
    }
    if (lower.contains('vi ') || lower.contains('vodafone')) {
      return const MerchantBrand(
        name: 'Vi',
        icon: Icons.phone_android_rounded,
        backgroundColor: Color(0xFFEC008C),
        iconColor: Colors.white,
        category: 'Recharge',
      );
    }
    if (lower.contains('bsnl')) {
      return const MerchantBrand(
        name: 'BSNL',
        icon: Icons.phone_android_rounded,
        backgroundColor: Color(0xFF005BBB),
        iconColor: Colors.white,
        category: 'Recharge',
      );
    }
    if (_isInsurance(lower)) {
      return MerchantBrand(
        name: _insuranceName(lower),
        icon: Icons.shield_rounded,
        backgroundColor: const Color(0xFF0B6E4F),
        iconColor: Colors.white,
        category: 'Insurance',
      );
    }
    if (direction == 'credit' || lower.contains('salary') || lower.contains('deposit')) {
      return MerchantBrand(
        name: effectiveTitle.isEmpty ? 'Salary Deposit' : effectiveTitle,
        icon: Icons.account_balance_wallet_rounded,
        backgroundColor: const Color(0xFF1B4D3E),
        iconColor: const Color(0xFF1DB954),
        category: 'Income',
      );
    }

    // Default fallback based on labelType
    switch (labelType) {
      case 'atm':
        return MerchantBrand(
          name: effectiveTitle.isEmpty ? 'ATM Cash' : effectiveTitle,
          icon: Icons.local_atm_rounded,
          backgroundColor: const Color(0xFF1A233A),
          iconColor: const Color(0xFF7C6AF7),
          category: 'ATM',
        );
      case 'upi':
        return MerchantBrand(
          name: effectiveTitle.isEmpty ? 'UPI Transfer' : effectiveTitle,
          icon: Icons.send_to_mobile_rounded,
          backgroundColor: const Color(0xFF2C223B),
          iconColor: const Color(0xFFE5A93C),
          category: 'Transfers',
        );
      default:
        return MerchantBrand(
          name: effectiveTitle.isEmpty ? 'Bank Transfer' : effectiveTitle,
          icon: direction == 'debit' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          backgroundColor: const Color(0xFF1E1E2C),
          iconColor: direction == 'debit' ? const Color(0xFFE8445A) : const Color(0xFF1DB954),
          category: 'Bank',
        );
    }
  }
}
