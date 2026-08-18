import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

/// AI service that auto-routes by key type:
///
/// • `gsk_…` (GROQ, the primary provider) → GROQ's OpenAI-compatible
///   endpoint, `openai/gpt-oss-120b` for chat/insights (best free reasoning)
///   and `groq/compound-mini` for categorization (fast, direct answers).
/// • `sk-or-…` (OpenRouter) → chat-completions, model `openrouter/free`.
/// • anything else (Gemini `AIza…`) → Google's native Gemini endpoint,
///   `gemini-flash-lite-latest` (free tier fallback).
enum _AiProvider { groq, openRouter, gemini }

class AiService {
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Free-tier Gemini model verified working on a real key (fallback only).
  static const String _geminiModel = 'gemini-flash-lite-latest';

  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  /// Best quality model on GROQ's free tier (verified on the live key).
  static const String _groqChatModel = 'openai/gpt-oss-120b';

  /// Fast model for batch categorization — answers directly instead of burning
  /// tokens on hidden reasoning (gpt-oss-20b and qwen reason first; verified).
  static const String _groqCategorizeModel = 'groq/compound-mini';

  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  /// OpenRouter router that forwards to the best currently-free model —
  /// requires no credits, so any valid key works.
  static const String _openRouterModel = 'openrouter/free';

  /// Storage key for the AI API key. Legacy `GEMINI_API_KEY` values written by
  /// older builds are read as a fallback and re-saved under the new key.
  static const String apiKeyStorageKey = 'AI_API_KEY';
  static const String legacyApiKeyStorageKey = 'GEMINI_API_KEY';

  /// Cap responses so a chat reply never burns the free token budget.
  static const int _maxTokens = 1024;

  static final _upiRe = RegExp(r'\b[\w.+-]+@[\w.-]+\b');
  static final _phoneRe = RegExp(r'\b\d{10}\b');
  static final _refRe = RegExp(r'\b\d{10,}\b');
  static final _balanceRe = RegExp(
    r'\b(?:Avl\s*bal|Bal|balance)\b\s*:?\s*(?:Rs\.?|INR)?\s*[\d,]+(?:\.\d+)?',
    caseSensitive: false,
  );
  final SecureStorageService _secureStorage;

  AiService([SecureStorageService? secureStorage])
      : _secureStorage = secureStorage ?? SecureStorageService();

  static bool isGroqKey(String key) => key.startsWith('gsk_');

  static bool isOpenRouterKey(String key) => key.startsWith('sk-or-');

  _AiProvider _providerFor(String key) {
    if (isGroqKey(key)) return _AiProvider.groq;
    if (isOpenRouterKey(key)) return _AiProvider.openRouter;
    return _AiProvider.gemini;
  }

  /// Strip PII (UPI ids, phone numbers, ref numbers, balances) before anything
  /// leaves the device.
  String redact(String text) => text
      .replaceAll(_balanceRe, '[balance]')
      .replaceAll(_upiRe, '[upi]')
      .replaceAll(_phoneRe, '[phone]')
      .replaceAll(_refRe, '[ref]');

  /// Extracts assistant text deltas from OpenAI-compatible SSE chunk lines.
  /// Skips keep-alives and the terminal `[DONE]` marker. Pure and
  /// unit-testable without a network.
  @visibleForTesting
  static List<String> sseDeltas(Iterable<String> lines) {
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring('data:'.length).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final obj = jsonDecode(payload) as Map<String, dynamic>;
        final choices = obj['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = choices[0]['delta'];
        if (delta is Map &&
            delta['content'] is String &&
            (delta['content'] as String).isNotEmpty) {
          out.add(delta['content'] as String);
        }
      } catch (_) {
        // Partial or malformed line mid-stream — skip it.
      }
    }
    return out;
  }

  /// The chat's system prompt: current date (the model has no clock) plus the
  /// formatting rules that replace the old guardrails — no em dashes, no
  /// star bullets, prefer tables. Visible for testing.
  @visibleForTesting
  static String systemPromptFor(String today) =>
      'Today is $today (device local time).\n'
      'You are ROZZ, the assistant in a personal finance app. Be warm, '
      'concise and direct.\n'
      'A snapshot of the user\'s real finances, including their full '
      'transaction history, may be included in the message. Use it to answer '
      'finance questions accurately. For anything else, answer normally from '
      'general knowledge.\n'
      'Formatting rules:\n'
      '- Never use em dashes (—). Use commas, colons or periods.\n'
      '- Do not format lists with leading stars or asterisks. Use plain '
      'sentences or short paragraphs.\n'
      '- When comparing figures, listing items, or showing a breakdown, '
      'prefer a markdown table with pipes and a header row over bullets.\n'
      '- Keep answers short and skimmable. Bold key numbers.';

  String _promptWithContext(String? context, String query) =>
      context == null || context.isEmpty
          ? query
          : 'Here is a snapshot of the user\'s finances:\n$context\n\n'
              'Question: $query';

  static const String noKeyMessage =
      'ROZZ\'s AI brain isn\'t configured yet. Add your API key — a free GROQ '
      'key (gsk_…, console.groq.com) or an OpenRouter key (sk-or-…) — and I '
      'can answer finance questions from your records.';

  /// Returned when the stored key is rejected by the provider (401/403).
  static const String invalidKeyMessage =
      'The saved API key was rejected — check it in settings and try again.';

  /// Free-tier APIs throttle quickly, so chat sends are spaced out and
  /// transient 429s get two quiet retries before the user sees anything.
  static const Duration chatMinGap = Duration(seconds: 4);
  static DateTime _lastChatRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// One completion call, routed by key type. Returns the reply text, or null
  /// when the request failed for a non-transient reason. [history] carries
  /// prior turns (role/content) so follow-up questions keep their context.
  /// [model] overrides the provider's default (GROQ chat vs fast categorization).
  Future<String?> _completion(
    String apiKey,
    String prompt, {
    required bool retryOnRateLimit,
    String? systemPrompt,
    List<Map<String, String>> history = const [],
    String? model,
  }) async {
    final provider = _providerFor(apiKey);
    final url = switch (provider) {
      _AiProvider.groq => Uri.parse(_groqUrl),
      _AiProvider.openRouter => Uri.parse(_openRouterUrl),
      _AiProvider.gemini => Uri.parse(
          '$_geminiBaseUrl/$_geminiModel:generateContent?key=$apiKey'),
    };
    final isOpenAi = provider != _AiProvider.gemini;
    final headers = isOpenAi
        ? {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          }
        : {'Content-Type': 'application/json'};
    final resolvedModel = model ??
        (provider == _AiProvider.groq ? _groqChatModel : _openRouterModel);
    final body = isOpenAi
        ? _openAiBody(resolvedModel, history, prompt, systemPrompt)
        : _geminiBody(history, prompt, systemPrompt);

    for (var attempt = 0; attempt <= (retryOnRateLimit ? 2 : 0); attempt++) {
      try {
        final response = await http
            .post(url, headers: headers, body: body)
            // 45s: free-tier cold starts on mobile routinely exceed 30s.
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final text = isOpenAi
              ? _parseOpenAi(response.body)
              : _parseGemini(response.body);
          if (text != null) return text.trim();
          return null;
        }
        // Invalid/revoked key — don't retry, tell the user it's the key.
        if (response.statusCode == 401 || response.statusCode == 403) {
          return invalidKeyMessage;
        }
        // 429 = quota/rate limit (free tiers throttle hard); retry quietly.
        if (response.statusCode == 429 && retryOnRateLimit) {
          if (attempt < 2) {
            await Future<void>.delayed(Duration(seconds: 3 * (attempt + 1)));
            continue;
          }
          return null;
        }
        return null;
      } catch (e) {
        if (attempt < 2 && retryOnRateLimit) {
          await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  String _openAiBody(
    String model,
    List<Map<String, String>> history,
    String prompt,
    String? systemPrompt,
  ) =>
      jsonEncode({
        'model': model,
        'max_tokens': _maxTokens,
        'messages': [
          if (systemPrompt != null)
            {'role': 'system', 'content': systemPrompt},
          ...history.map((m) => {
                'role': m['role'],
                'content': redact(m['content'] ?? ''),
              }),
          {'role': 'user', 'content': redact(prompt)},
        ],
      });

  String _geminiBody(
    List<Map<String, String>> history,
    String prompt,
    String? systemPrompt,
  ) =>
      jsonEncode({
        'contents': [
          ...history.map((m) => {
                'role': m['role'] == 'user' ? 'user' : 'model',
                'parts': [
                  {'text': redact(m['content'] ?? '')},
                ],
              }),
          {
            'role': 'user',
            'parts': [
              {'text': redact(prompt)},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': _maxTokens},
        if (systemPrompt != null)
          'system_instruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
      });

  String? _parseOpenAi(String body) {
    final data = jsonDecode(body);
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    final choice = choices[0];
    final content = choice['message']['content'];
    // openrouter/free can route to reasoning models whose content is a list
    // of parts (or null) — accept all three shapes.
    String? text;
    if (content is String) text = content;
    if (content is List) {
      final parts = content.map((p) => p is Map ? p['text'] : p).whereType<String>();
      if (parts.isNotEmpty) text = parts.join('');
    }
    // A reasoning model can burn its whole budget on `reasoning` and emit an
    // empty content — that's a failure, not an answer.
    if (text == null || text.trim().isEmpty) return null;
    // Truncated by max_tokens: say so instead of ending mid-sentence.
    if (choice['finish_reason'] == 'length') {
      return '$text\n\n…(answer cut off)';
    }
    return text;
  }

  String? _parseGemini(String body) {
    final data = jsonDecode(body);
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final candidate = candidates[0];
    final text = candidate['content']['parts'][0]['text'] as String?;
    if (text == null) return null;
    if (candidate['finishReason'] == 'MAX_TOKENS') {
      return '$text\n\n…(answer cut off)';
    }
    return text;
  }

  /// Answers a question with optional real context (a compact finance summary
  /// and the user's full transaction history). The system prompt carries the
  /// CURRENT date (the model otherwise infers "today" from the newest
  /// transaction rows and answers wrong) plus the formatting rules. [history]
  /// carries prior chat turns so follow-ups keep their context.
  Future<String> askFinancialAssistant(
    String query, {
    String? context,
    List<Map<String, String>> history = const [],
  }) async {
    // A throwing read (broken Keystore on some devices) must not escape into
    // the chat UI as an unhandled async error.
    String? apiKey;
    try {
      apiKey = await _readKeyOrNull();
    } catch (e) {
      debugPrint('Key read failed: $e');
    }
    if (apiKey == null || apiKey.isEmpty) return noKeyMessage;

    // Client-side throttle: space chat requests so bursts stay polite to the
    // rate limiter (and nothing in the background competes for the quota).
    final sinceLast = DateTime.now().difference(_lastChatRequest);
    if (sinceLast < chatMinGap) {
      await Future<void>.delayed(chatMinGap - sinceLast);
    }
    _lastChatRequest = DateTime.now();

    // Device-local date, injected fresh per request — the model has no clock.
    final now = DateTime.now();
    final today = DateFormat('d MMMM yyyy').format(now);

    final reply = await _completion(
      apiKey,
      _promptWithContext(context, query),
      retryOnRateLimit: true,
      systemPrompt: systemPromptFor(today),
      history: history,
    );
    if (reply != null) return reply;
    return 'I couldn\'t reach my AI service right now (it may be rate-limited '
        'or out of credits). Try again in a moment.';
  }

  /// Streams a reply token-by-token (OpenAI-compatible SSE) for a
  /// ChatGPT-style experience. GROQ and OpenRouter stream; Gemini falls back
  /// to a single non-streaming call. Same routing, throttling, redaction and
  /// system prompt as [askFinancialAssistant].
  Stream<String> streamFinancialAssistant(
    String query, {
    String? context,
    List<Map<String, String>> history = const [],
  }) async* {
    String? apiKey;
    try {
      apiKey = await _readKeyOrNull();
    } catch (e) {
      debugPrint('Key read failed: $e');
    }
    if (apiKey == null || apiKey.isEmpty) {
      yield noKeyMessage;
      return;
    }

    final provider = _providerFor(apiKey);
    final sinceLast = DateTime.now().difference(_lastChatRequest);
    if (sinceLast < chatMinGap) {
      await Future<void>.delayed(chatMinGap - sinceLast);
    }
    _lastChatRequest = DateTime.now();

    // Gemini has a different streaming wire format — fall back to the
    // non-streaming path and emit the full answer at once.
    if (provider == _AiProvider.gemini) {
      yield await askFinancialAssistant(query, context: context, history: history);
      return;
    }

    final now = DateTime.now();
    final today = DateFormat('d MMMM yyyy').format(now);
    final url = provider == _AiProvider.groq
        ? Uri.parse(_groqUrl)
        : Uri.parse(_openRouterUrl);
    final model = provider == _AiProvider.groq
        ? _groqChatModel
        : _openRouterModel;
    final body = jsonEncode({
      'model': model,
      'max_tokens': _maxTokens,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': systemPromptFor(today)},
        ...history.map((m) => {
              'role': m['role'],
              'content': redact(m['content'] ?? ''),
            }),
        {'role': 'user', 'content': redact(_promptWithContext(context, query))},
      ],
    });

    final request = http.Request('POST', url)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = body;

    http.StreamedResponse response;
    try {
      // 45s: free-tier cold starts on mobile routinely exceed 30s.
      response = await request.send().timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint('Chat stream failed: $e');
      yield 'I couldn\'t reach my AI service right now. Try again in a moment.';
      return;
    }

    // Invalid/revoked key — don't retry, tell the user it's the key.
    if (response.statusCode == 401 || response.statusCode == 403) {
      yield invalidKeyMessage;
      return;
    }
    if (response.statusCode != 200) {
      debugPrint('Chat stream status: ${response.statusCode}');
      yield 'I couldn\'t reach my AI service right now (it may be rate-limited '
          'or out of credits). Try again in a moment.';
      return;
    }

    try {
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        for (final delta in sseDeltas([line])) {
          yield delta;
        }
      }
    } catch (e) {
      debugPrint('Chat stream read failed: $e');
    }
  }

  Future<String?> categorizeTransaction(String narration, {int retries = 2}) async {
    final apiKey = await _readKeyOrNull();
    if (apiKey == null) return null;
    final prompt =
        'Categorize this bank transaction narration into a single word category '
        '(e.g., Food, Transport, Shopping, Rent, Salary). Narration: $narration';
    final reply = await _completion(
      apiKey,
      prompt,
      retryOnRateLimit: retries > 0,
      model: isGroqKey(apiKey) ? _groqCategorizeModel : null,
    );
    // A rejected key is not a category — treat it as failure.
    return reply == invalidKeyMessage ? null : reply;
  }

  Future<String?> getFinancialInsight(List<String> recentTransactions, {int retries = 2}) async {
    final apiKey = await _readKeyOrNull();
    if (apiKey == null) return null;
    final prompt =
        'Analyze these recent transactions and give a 1-sentence financial tip: '
        '${recentTransactions.join(", ")}';
    final reply = await _completion(apiKey, prompt, retryOnRateLimit: retries > 0);
    return reply == invalidKeyMessage ? null : reply;
  }

  /// Reads the stored key (new name, then legacy `GEMINI_API_KEY`), swallowing
  /// storage errors (broken Keystore) so background categorization never
  /// throws. Null = no usable key.
  Future<String?> _readKeyOrNull() async {
    try {
      var key = await _secureStorage.readValue(apiKeyStorageKey);
      if (key == null || key.isEmpty) {
        key = await _secureStorage.readValue(legacyApiKeyStorageKey);
        if (key != null && key.isNotEmpty) {
          // Migrate: re-save under the new name so the fallback read ends.
          await _secureStorage.writeValue(apiKeyStorageKey, key);
        }
      }
      return (key == null || key.isEmpty) ? null : key;
    } catch (e) {
      debugPrint('Key read failed: $e');
      return null;
    }
  }
}
