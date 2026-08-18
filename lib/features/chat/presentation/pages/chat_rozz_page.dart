import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/core/services/ai_service.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/mab/domain/usecases/estimate_mab_fine.dart';
import 'package:rozz/features/onboarding/presentation/pages/settings_page.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';
import 'package:rozz/shared/utils/sender_label_resolver.dart';

/// ROZZ AI chat, ChatGPT-style: replies stream in token by token, assistant
/// answers render as rich markdown (tables supported), the composer docks at
/// the bottom with a stop button while streaming, and suggestion chips offer
/// a starting point on the empty state. The prompt carries the user's FULL
/// local record: every transaction (not just a recent slice), the month
/// summary, categories, income, subscriptions, upcoming charges and the MAB
/// forecast, so the model can answer any question about the money. PII is
/// still redacted before anything leaves the device.
class ChatRozzPage extends StatefulWidget {
  final AiService aiService;
  final SecureStorageService secureStorage;
  final TransactionRepository transactionRepository;

  /// Invoked when the user taps the close button. The chat is hosted as a tab
  /// (never pushed onto the navigator), so the host decides what "close" means
  /// — typically switching back to the home tab.
  final VoidCallback? onClose;

  const ChatRozzPage({
    super.key,
    required this.aiService,
    required this.secureStorage,
    required this.transactionRepository,
    this.onClose,
  });

  @override
  State<ChatRozzPage> createState() => _ChatRozzPageState();
}

class _ChatRozzPageState extends State<ChatRozzPage> {
  static const _apiKeyStorageKey = AiService.apiKeyStorageKey;
  static const _legacyApiKeyStorageKey = AiService.legacyApiKeyStorageKey;

  /// When the user taps "skip for now", persist it so the setup screen does
  /// not come back on every launch (memory-only flags made it a nag loop).
  static const _skipStorageKey = 'chat_skip';

  static const _suggestions = [
    'how much did I spend this month?',
    'what\'s my MAB right now?',
    'list my subscriptions',
    'where does my money go?',
  ];

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  /// Streaming state: the in-flight assistant reply, fed by
  /// [AiService.streamFinancialAssistant], and its subscription (so the user
  /// can stop mid-answer).
  StreamSubscription<String>? _streamSub;
  String? _streamingBuffer;

  bool _isTyping = false;
  bool _isSavingKey = false;

  /// null = not checked yet, true = key present, false = missing.
  bool? _hasApiKey;

  final ScrollController _scrollController = ScrollController();

  /// Auto-scroll only when the user is already at the bottom — yanking a
  /// reader who scrolled up to re-check a balance is the classic chat bug.
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _hasStoredKey() async {
    try {
      final key = await widget.secureStorage.readValue(_apiKeyStorageKey);
      if (key != null && key.isNotEmpty) return true;
      // Legacy key from older builds — treat as present (AiService migrates it).
      final legacy = await widget.secureStorage.readValue(_legacyApiKeyStorageKey);
      return legacy != null && legacy.isNotEmpty;
    } catch (e) {
      debugPrint('Key check failed: $e');
      return false;
    }
  }

  Future<void> _checkApiKey() async {
    var hasKey = false;
    try {
      hasKey = await _hasStoredKey();
      if (!hasKey) {
        final skipped = await widget.secureStorage.readValue(_skipStorageKey);
        hasKey = skipped == 'true';
      }
    } catch (e) {
      // Broken Keystore reads must not leave the screen stuck — default to
      // showing the setup screen rather than a forever-blank chat.
      debugPrint('Key check failed: $e');
    }
    if (mounted) {
      setState(() => _hasApiKey = hasKey);
    }
  }

  Future<void> _saveApiKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty || _isSavingKey) return;
    setState(() => _isSavingKey = true);
    try {
      await widget.secureStorage.writeValue(_apiKeyStorageKey, key);
      // Read-back verify: a write that silently failed (Keystore errors are
      // common on some devices) must not claim success.
      final stored = await widget.secureStorage.readValue(_apiKeyStorageKey);
      if (stored != key) {
        throw Exception('write did not persist');
      }
      if (mounted) setState(() => _hasApiKey = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('couldn\'t save the key: $e',
                style: GoogleFonts.dmSans(fontSize: 13)),
            backgroundColor: RozzColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingKey = false);
    }
  }

  Future<void> _skipKeySetup() async {
    HapticFeedback.lightImpact();
    try {
      await widget.secureStorage.writeValue(_skipStorageKey, 'true');
    } catch (e) {
      debugPrint('Skip flag write failed: $e');
    }
    if (mounted) setState(() => _hasApiKey = true);
  }

  /// Builds a snapshot of the user's finances for the AI: the month summary,
  /// MAB forecast, and the FULL transaction ledger (every row, newest first),
  /// so the model can answer across months, not just about the current one.
  /// PII (UPI ids, phones, refs, balances) is stripped by [AiService.redact]
  /// when the request is assembled.
  Future<String> _buildContext(String query) async {
    final state = context.read<InsightsBloc>().state;
    if (state is! InsightsLoaded) return '';
    final s = state.summary;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    // Device-local now, not the insights state (which may be stale if the
    // user hasn't refreshed this month) — the "as of" label keeps the model
    // from treating old rows as recent.
    final now = DateTime.now();
    final asOf = DateFormat('d MMMM yyyy').format(now);

    final lines = <String>[
      'Finance summary for ${DateFormat('MMMM yyyy').format(now)}, as of $asOf:',
      'Received: ${currency.format(s.received)} (prior month: ${currency.format(s.priorReceived)})',
      'Spent: ${currency.format(s.spent)} (prior month: ${currency.format(s.priorSpent)})',
      'Saved: ${currency.format(s.saved)} (prior month: ${currency.format(s.priorSaved)})',
      if (s.categories.isNotEmpty)
        'Spending by category: ${s.categories.map((c) => '${c.category} ${currency.format(c.amount)}').join(', ')}',
      if (state.incomeSources.isNotEmpty)
        'Money in by sender: ${state.incomeSources.take(8).map((src) => '${src.recipient} ${currency.format(src.amount)} (${src.count}x)').join(', ')}',
      if (state.recurringIncome.isNotEmpty)
        'Recurring income: ${state.recurringIncome.take(5).map((r) => '${r.displayName} ~${currency.format(r.typicalAmount)}/mo, seen ${r.monthsSeen} months, ${r.arrivedThisMonth ? 'arrived this month' : 'not yet this month (expected ${r.expectedNext == null ? 'irregular' : DateFormat('d MMM').format(r.expectedNext!)})'}').join('; ')}',
      if (state.subscriptions.isNotEmpty)
        'Subscriptions: ${state.subscriptions.map((sub) => sub.amountVaries ? '${sub.merchant} ${currency.format(sub.minAmount)}-${currency.format(sub.maxAmount)}/mo (${sub.occurrences}x)' : '${sub.merchant} ${currency.format(sub.monthlyAmount)}/mo (${sub.occurrences}x)').join(', ')}',
      if (state.upcomingCharges.isNotEmpty)
        'Upcoming charges: ${state.upcomingCharges.map((c) => '${c.merchant} ${currency.format(c.amount)} on ${DateFormat('d MMM').format(c.predictedDate)}').join(', ')}',
    ];

    // MAB forecast + penalty for the current month.
    final mabState = context.read<MabBloc>().state;
    if (mabState is MabLoaded) {
      final status = mabState.status;
      final fine = EstimateMabFine()(
        mab: status.currentMab,
        requiredMin: status.requiredMin,
      );
      lines.add(
        'MAB ${DateFormat('MMM yyyy').format(DateTime(mabState.year, mabState.month))}: '
        'current MAB ${currency.format(status.currentMab)}, required min '
        '${currency.format(status.requiredMin)}, days recorded '
        '${status.daysRecorded}, ${fine.hasShortfall ? 'estimated penalty ${currency.format(fine.fine)} + GST (${fine.shortfallPercent.toStringAsFixed(0)}% short)' : 'no penalty expected'}.',
      );
    }

    // Full ledger, every transaction, so the AI can answer about any month.
    final txs = await widget.transactionRepository.getAllTransactions();
    if (txs.isNotEmpty) {
      lines.add('All transactions (newest first):');
      for (final t in txs) {
        final dt = DateTime.parse(t.date).toLocal();
        final brand = MerchantBrandResolver.resolve(
          t.recipientName ?? '',
          t.labelType,
          t.direction,
          rawSms: t.rawSms ?? '',
        );
        final senderLabel = resolveSenderLabel(
          t.upiId ?? t.recipientName ?? '',
          state.senderLabels,
        );
        final name = senderLabel ?? brand.name;
        lines.add(
          '- ${DateFormat('d MMM yyyy, h:mm a').format(dt)} | '
          '${t.direction == 'debit' ? 'spent' : 'received'} '
          '${currency.format(t.amount)} | $name'
          '${t.category == null ? '' : ' | ${t.category}'}',
        );
      }
    }

    return lines.join('\n');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    _controller.clear();
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'time': 'Just now',
      });
      _isTyping = true;
      _streamingBuffer = '';
    });
    _scrollToBottomIfSticky();

    // Prior turns (most recent 10, excluding the message just added) so
    // follow-up questions keep their context.
    final priorCount = _messages.length - 1;
    final start = priorCount <= 10 ? 0 : priorCount - 10;
    final history = _messages
        .skip(start)
        .take(10)
        .map((m) => {
              'role': m['sender'] == 'user' ? 'user' : 'assistant',
              'content': m['text'] ?? '',
            })
        .toList();

    try {
      _streamSub = widget.aiService
          .streamFinancialAssistant(
            text,
            context: await _buildContext(text),
            history: history,
          )
          .listen(
        (delta) {
          if (!mounted) return;
          setState(() => _streamingBuffer = (_streamingBuffer ?? '') + delta);
          _scrollToBottomIfSticky();
        },
        onError: (Object e) {
          debugPrint('Chat stream error: $e');
          _finishStreaming('Something went wrong while asking ROZZ — check '
              'your key in settings and try again.');
        },
        onDone: () => _finishStreaming(),
      );
    } catch (e) {
      // A storage or provider error must not leave the typing bubble up
      // forever — surface it as a message instead.
      debugPrint('Chat request failed: $e');
      _finishStreaming('Something went wrong while asking ROZZ — check your '
          'key in settings and try again.');
    }
  }

  /// Finalizes the in-flight reply: moves the accumulated streamed text into
  /// the message list (or uses [fallback] when the stream produced nothing).
  void _finishStreaming([String? fallback]) {
    if (!mounted) return;
    final buffer = _streamingBuffer ?? '';
    final text = buffer.trim().isNotEmpty ? buffer.trim() : (fallback ?? '');
    setState(() {
      if (text.isNotEmpty) {
        _messages.add({
          'sender': 'rozz',
          'text': text,
          'time': 'Just now',
        });
      }
      _isTyping = false;
      _streamingBuffer = null;
      _streamSub?.cancel();
      _streamSub = null;
    });
    _scrollToBottomIfSticky();
  }

  /// Stops the in-flight answer and keeps whatever has streamed so far.
  void _stopStreaming() {
    _streamSub?.cancel();
    _streamSub = null;
    _finishStreaming();
  }

  void _sendSuggestion(String suggestion) {
    _controller.text = suggestion;
    _sendMessage();
  }

  /// Jumps to the newest message after an append — but only if the user
  /// hasn't scrolled up to re-read something.
  void _scrollToBottomIfSticky() {
    if (!_stickToBottom || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (widget.onClose != null) {
              widget.onClose!();
            } else {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.close, color: RozzColors.textPrimary),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: RozzColors.gold, size: 18),
            const SizedBox(width: 8),
            Text(
              'ROZZ',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: RozzColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              // Key may have been added/cleared there — refresh the check.
              if (mounted) _checkApiKey();
            },
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: RozzColors.textSecondary),
          ),
        ],
      ),
      body: SafeArea(
        // ChatGPT-style: a narrow centered column so long lines stay readable.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? (_hasApiKey == false ? _buildKeySetup() : _buildEmptyChat())
                      : NotificationListener<UserScrollNotification>(
                          onNotification: (n) {
                            if (n.direction == ScrollDirection.reverse) {
                              _stickToBottom = false;
                            } else if (n.direction == ScrollDirection.forward &&
                                _scrollController.position.pixels >=
                                    _scrollController.position.maxScrollExtent - 24) {
                              _stickToBottom = true;
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            itemCount: _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                return (_streamingBuffer ?? '').isEmpty
                                    ? const _TypingBubble()
                                    : _buildStreamingBubble();
                              }
                              final msg = _messages[index];
                              final isUser = msg['sender'] == 'user';
                              return _buildChatBubble(msg['text']!, isUser);
                            },
                          ),
                        ),
                ),

                // Suggestion chips: a nudge on the first message only.
                if (_messages.isEmpty && _hasApiKey != false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in _suggestions)
                          _SuggestionChip(label: s, onTap: () => _sendSuggestion(s)),
                      ],
                    ),
                  ),

                // Docked composer (stop button replaces send while streaming).
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: RozzColors.s1,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: RozzColors.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.dmSans(
                              color: RozzColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ask anything about your money...',
                              hintStyle: GoogleFonts.dmSans(
                                color: RozzColors.textMuted,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isTyping ? _stopStreaming : _sendMessage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _isTyping ? RozzColors.s2 : RozzColors.gold,
                              shape: BoxShape.circle,
                              border: _isTyping
                                  ? Border.all(color: RozzColors.expense)
                                  : null,
                            ),
                            child: Icon(
                              _isTyping ? Icons.stop_rounded : Icons.arrow_upward,
                              color: _isTyping ? RozzColors.expense : Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One-time setup: ROZZ's AI needs an API key, stored on-device. Shown only
  /// when the key is missing.
  Widget _buildKeySetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: RozzColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.key_rounded, color: RozzColors.gold, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'connect ROZZ\'s AI',
            style: GoogleFonts.syne(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'paste a free GROQ key (gsk_... from console.groq.com) or an '
            'OpenRouter key (sk-or-...) — it stays on your phone and answers '
            'from your own data.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.5,
              color: RozzColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _keyController,
            obscureText: true,
            style: const TextStyle(color: RozzColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'gsk_... (GROQ) or sk-or-...',
              hintStyle: const TextStyle(color: RozzColors.textMuted),
              filled: true,
              fillColor: RozzColors.s3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _saveApiKey(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSavingKey ? null : _saveApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: RozzColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'save key',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _skipKeySetup,
            child: Text(
              'skip for now',
              style: GoogleFonts.dmSans(fontSize: 12, color: RozzColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: RozzColors.gold, size: 40),
            const SizedBox(height: 16),
            Text(
              'How can I help with your money today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: RozzColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I read your full on-device records, so ask me about any month.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.5,
                color: RozzColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The in-flight assistant reply: raw streamed text with a blinking caret
  /// (ChatGPT shows the markdown being typed; tables snap in on completion).
  Widget _buildStreamingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              _streamingBuffer ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.5,
                color: RozzColors.textPrimary,
              ),
            ),
          ),
          const _BlinkingCaret(),
        ],
      ),
    );
  }

  /// User messages sit right in a soft bubble; assistant answers are plain,
  /// full-width markdown (tables, bold, code) with a copy button beneath.
  Widget _buildChatBubble(String text, bool isUser) {
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: RozzColors.s2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.4,
              color: RozzColors.textPrimary,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: text,
            styleSheet: _mdStyle(),
          ),
          const SizedBox(height: 6),
          _CopyButton(text: text),
        ],
      ),
    );
  }

  MarkdownStyleSheet _mdStyle() {
    final base = MarkdownStyleSheet.fromTheme(
      ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RozzColors.bg,
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
      ),
    );
    return base.copyWith(
      p: GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.55,
        color: RozzColors.textPrimary,
      ),
      strong: GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.bold,
        color: RozzColors.goldLight,
      ),
      em: GoogleFonts.dmSans(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: RozzColors.textSecondary,
      ),
      h1: GoogleFonts.syne(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
      ),
      h2: GoogleFonts.syne(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
      ),
      h3: GoogleFonts.syne(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
      ),
      listBullet: GoogleFonts.dmSans(
        fontSize: 14,
        color: RozzColors.textPrimary,
      ),
      blockquote: GoogleFonts.dmSans(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: RozzColors.textSecondary,
      ),
      blockquoteDecoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(8),
      ),
      code: GoogleFonts.dmMono(
        fontSize: 13,
        color: RozzColors.goldLight,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(10),
      ),
      tableHead: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: RozzColors.goldLight,
      ),
      tableBody: GoogleFonts.dmSans(
        fontSize: 13,
        height: 1.4,
        color: RozzColors.textPrimary,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      tableBorder: TableBorder.all(color: RozzColors.s3, width: 1),
    );
  }
}

/// ChatGPT-style blinking caret at the end of the streamed reply.
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.15).animate(_controller),
      child: const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 2),
        child: Text(
          '▌',
          style: TextStyle(color: RozzColors.gold, fontSize: 14),
        ),
      ),
    );
  }
}

/// Tappable suggestion that fills and sends the composer.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RozzColors.s1,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RozzColors.cardBorder),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: RozzColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Copies the assistant answer to the clipboard.
class _CopyButton extends StatelessWidget {
  final String text;

  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: text)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.copy_rounded, size: 13, color: RozzColors.textMuted),
          const SizedBox(width: 4),
          Text(
            'copy',
            style: GoogleFonts.dmSans(fontSize: 11, color: RozzColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// ChatGPT-style thinking indicator: an assistant-styled bubble (same colors
/// as real answers) with three bouncing dots. Renders in place of the answer
/// while the first streamed token is still on its way.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Staggered bounce: each dot peaks ~1/3 of a cycle apart.
              final t = (_controller.value - i * 0.25) % 1.0;
              final curve = Curves.easeInOut.transform(t);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: 0.25 + 0.75 * curve,
                  child: Transform.translate(
                    offset: Offset(0, -3 * curve),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: RozzColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}