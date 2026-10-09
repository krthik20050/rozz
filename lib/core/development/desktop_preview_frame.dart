import 'package:flutter/material.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/core/theme/colors.dart';

/// Development chrome around the actual app, not a duplicate mock interface.
class DesktopPreviewFrame extends StatefulWidget {
  const DesktopPreviewFrame({
    super.key,
    required this.child,
    required this.syncService,
    required this.onImported,
    required this.navigatorKey,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final TransactionSyncService syncService;
  final VoidCallback onImported;

  @override
  State<DesktopPreviewFrame> createState() => _DesktopPreviewFrameState();
}

class _DesktopPreviewFrameState extends State<DesktopPreviewFrame> {
  bool _busy = false;
  String _status = 'Synthetic data only. Restart clears this preview.';

  Future<void> _inject() async {
    final controller = TextEditingController(
      text:
          'Rs.250 credited to HDFC Bank A/c XX4321 from Aarav. '
          'Ref PREVIEWCREDIT${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final body = await showDialog<String>(
        context: widget.navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('Simulate a bank SMS'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                helperText: 'Use fictional data only.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (body == null || !mounted) return;
      setState(() => _busy = true);
      final saved = await widget.syncService.ingestSms({
        'body': body,
        'date': DateTime.now().millisecondsSinceEpoch,
      });
      if (!mounted) return;
      setState(
        () => _status = saved
            ? 'Imported through the real parser and ledger.'
            : 'No transaction or balance found in that message.',
      );
      if (saved) widget.onImported();
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Import failed. Check the development console.');
      }
    } finally {
      // Route animations may still use the controller after showDialog returns.
      // Dispose after the route has finished its reverse transition.
      Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF161620),
    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'ROZZ / WINDOWS PREVIEW',
                  style: TextStyle(color: RozzColors.gold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : _inject,
                  child: Text(_busy ? 'Importing...' : 'Simulate SMS'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 402, maxHeight: 874),
              child: LayoutBuilder(builder: (context, constraints) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: widget.child,
              )),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            _status,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

