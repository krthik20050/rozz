import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// ROZZ AI chat. Answers from the user's real local data: actual transactions,
/// the month's money in/out, category breakdown, subscriptions, upcoming
/// charges, recurring income, sender labels and the MAB forecast are bundled
/// into the prompt so the model reasons from facts, not guesses. Conversation
/// history is carried along so follow-up questions keep their context. No fake
/// seed messages, no hardcoded numbers.
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

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final List<Map<String, String>> _messages = [];

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

  /// Builds a COMPACT snapshot of the user's finances for the AI. The month
  /// summary + MAB always go (panel: a finance question phrased unusually must
  /// still find data — a missing summary is a wrong answer about money). The
  /// transaction rows are the only part gated by intent: non-financial
  /// questions ("what's the date?", "tell me a joke") never carry them, so
  /// the user's whole history doesn't leave the device for small talk.
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

    // Transaction rows: only for questions that look financial.
    if (isFinancialQuestion(query)) {
      final txs = await widget.transactionRepository.getAllTransactions();
      if (txs.isNotEmpty) {
        lines.add('Recent transactions (newest first):');
        for (final t in txs.take(15)) {
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
            '- ${DateFormat('d MMM, h:mm a').format(dt)} | '
            '${t.direction == 'debit' ? 'spent' : 'received'} '
            '${currency.format(t.amount)} | $name'
            '${t.category == null ? '' : ' | ${t.category}'}',
          );
        }
      }
    }

    return lines.join('\n');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'time': 'Just now',
      });
      _isTyping = true;
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

    String reply;
    try {
      reply = await widget.aiService.askFinancialAssistant(
        text,
        context: await _buildContext(text),
        history: history,
      );
    } catch (e) {
      // A storage or provider error must not leave the typing bubble up
      // forever — surface it as a message instead.
      debugPrint('Chat request failed: $e');
      reply = 'Something went wrong while asking ROZZ — check your key in '
          'settings and try again.';
    }
    if (!mounted) return;
    setState(() {
      _messages.add({
        'sender': 'rozz',
        'text': reply,
        'time': 'Just now',
      });
      _isTyping = false;
    });
    _scrollToBottomIfSticky();
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
              'CHAT WITH ROZZ',
              style: GoogleFonts.dmSans(
                fontSize: 13,
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
        child: Column(
          children: [
            // Messages List (typing bubble lives inside it so scrolling
            // follows it naturally).
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) return const _TypingBubble();
                          final msg = _messages[index];
                          final isUser = msg['sender'] == 'user';
                          return _buildChatBubble(msg['text']!, isUser, msg['time']!);
                        },
                      ),
                    ),
            ),

            // Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: RozzColors.s1,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: RozzColors.gold.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: RozzColors.gold.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: RozzColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: GoogleFonts.dmSans(color: RozzColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ask anything...',
                          hintStyle: GoogleFonts.dmSans(color: RozzColors.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: RozzColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            'only from your own data.',
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, color: RozzColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            'ask me anything — finance questions read your on-device records.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: RozzColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser, String time) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? RozzColors.s2 : RozzColors.s1,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser ? RozzColors.cardBorder : RozzColors.gold.withOpacity(0.3),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: RozzColors.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// ChatGPT-style thinking indicator: an assistant-styled bubble (same colors
/// as real answers) with three bouncing dots. Renders in place of the answer
/// while the request is in flight.
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: RozzColors.s1,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: RozzColors.gold.withValues(alpha: 0.3)),
        ),
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
      ),
    );
  }
}
