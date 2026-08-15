import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:rozz/core/security/secure_storage_service.dart';

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static final _upiRe = RegExp(r'\b[\w.+-]+@[\w.-]+\b');
  static final _phoneRe = RegExp(r'\b\d{10}\b');
  static final _refRe = RegExp(r'\b\d{10,}\b');
  static final _balanceRe = RegExp(
    r'\b(?:Avl\s*bal|Bal|balance)\b\s*:?\s*(?:Rs\.?|INR)?\s*[\d,]+(?:\.\d+)?',
    caseSensitive: false,
  );
  final SecureStorageService _secureStorage;

  GeminiService(this._secureStorage);

  /// Strip PII (UPI ids, phone numbers, ref numbers, balances) before anything
  /// leaves the device. Balance first — its commas hide it from the digit regexes.
  String redact(String text) => text
      .replaceAll(_balanceRe, '[balance]')
      .replaceAll(_upiRe, '[upi]')
      .replaceAll(_phoneRe, '[phone]')
      .replaceAll(_refRe, '[ref]');

  Future<String?> categorizeTransaction(String narration, {int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        final apiKey = await _secureStorage.readValue('GEMINI_API_KEY');
        if (apiKey == null) return null;

        final response = await http.post(
          Uri.parse('$_baseUrl?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': 'Categorize this bank transaction narration into a single word category (e.g., Food, Transport, Shopping, Rent, Salary). Narration: ${redact(narration)}'
                  }
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return text.trim();
        } else if (response.statusCode == 429) {
          if (i < retries) await Future.delayed(Duration(seconds: 2 * (i + 1)));
          continue;
        }
        return null;
      } catch (e) {
        if (e is TimeoutException && i < retries) continue;
        // ignore: avoid_print
        print('GeminiService Error: $e');
        return null;
      }
    }
    return null;
  }

  Future<String?> getFinancialInsight(List<String> recentTransactions, {int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        final apiKey = await _secureStorage.readValue('GEMINI_API_KEY');
        if (apiKey == null) return null;

        final prompt = 'Analyze these recent transactions and give a 1-sentence financial tip: ${redact(recentTransactions.join(", "))}';

        final response = await http.post(
          Uri.parse('$_baseUrl?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [{'text': prompt}]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['candidates'][0]['content']['parts'][0]['text'] as String;
        } else if (response.statusCode == 429) {
          if (i < retries) await Future.delayed(Duration(seconds: 2 * (i + 1)));
          continue;
        }
        return null;
      } catch (e) {
        if (e is TimeoutException && i < retries) continue;
        return null;
      }
    }
    return null;
  }
}

