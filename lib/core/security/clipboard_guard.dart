import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Clears financial-looking content from the system clipboard whenever the
/// app is fully backgrounded ([AppLifecycleState.paused] only). Transient
/// `inactive` events — the notification shade, a permission dialog, the app
/// switcher — never wipe the clipboard, since it's a shared system resource.
///
/// Usage:
/// ```dart
/// final guard = ClipboardGuard();
/// guard.start();   // in initState
/// guard.dispose(); // in dispose
/// ```
class ClipboardGuard extends WidgetsBindingObserver {
  bool _active = false;

  /// Begin monitoring app lifecycle.
  void start() {
    _active = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop monitoring.
  void dispose() {
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active || state != AppLifecycleState.paused) return;
    _clearClipboard();
  }

  Future<void> _clearClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty || !isFinancialText(text)) return;
      await Clipboard.setData(const ClipboardData(text: ''));
      debugPrint('Clipboard cleared: contained financial data');
    } catch (e) {
      debugPrint('Clipboard clear failed: $e');
    }
  }

  /// Only tokens specific enough to be finance-related — deliberately not
  /// broad substrings like `@`, `ref`, or `acc` that would match emails or
  /// ordinary prose.
  static bool isFinancialText(String text) {
    final lower = text.toLowerCase();
    const tokens = [
      'upi', 'rs.', 'inr', '₹', 'debit', 'credit', 'balance', 'a/c',
      'hdfc', 'sbi', 'icici', 'paytm', 'gpay', 'phonepe', 'bhim',
      'netbanking',
    ];
    return tokens.any(lower.contains);
  }
}