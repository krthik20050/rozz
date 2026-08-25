import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/services/ai_service.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

void main() {
  final service = AiService(SecureStorageService());

  test('redact strips balances, UPI ids, phones, and refs', () {
    const sms = 'Rs.340.00 debited from A/c XX1234 to test@okaxis on 04-03-26. '
        'Ref 421874651243. Avl bal:Rs.42,340.00 Contact 9876543210';
    final out = service.redact(sms);
    expect(out, isNot(contains('42,340')));
    expect(out, isNot(contains('test@okaxis')));
    expect(out, isNot(contains('421874651243')));
    expect(out, isNot(contains('9876543210')));
    expect(out, contains('[balance]'));
  });

  test('redact keeps the amount (needed for categorization)', () {
    const sms = 'Rs.340.00 debited from A/c XX1234 to SWIGGY via UPI Ref 421874651243. Avl bal:Rs.42,340.00';
    expect(service.redact(sms), contains('340.00'));
  });

  test('sseDeltas extracts content, skips keep-alives and [DONE]', () {
    const lines = [
      'data: {"choices":[{"delta":{"role":"assistant","content":""}}]}',
      'data: {"choices":[{"delta":{"content":"Here"}}]}',
      ': keep-alive',
      'data: {"choices":[{"delta":{"content":" is "}}]}',
      '',
      'data: {"choices":[{"delta":{"content":"a table"}}]}',
      'data: {"choices":[{"delta":{"content":"..."}}]}',
      'data: [DONE]',
      'garbage line',
    ];
    expect(AiService.sseDeltas(lines), ['Here', ' is ', 'a table', '...']);
  });

  test('sseDeltas tolerates malformed payloads mid-stream', () {
    expect(AiService.sseDeltas(['data: not-json', 'data: {"choices":[]}']), isEmpty);
  });

  test('sseDeltas skips reasoning deltas (gpt-oss hidden CoT) and keeps content', () {
    // GROQ's gpt-oss-120b streams reasoning_content during its thinking phase,
    // then real content. The reasoning must not leak to the chat and empty
    // reasoning chunks must not be treated as the answer.
    const lines = [
      'data: {"choices":[{"delta":{"role":"assistant","content":""}}]}',
      'data: {"choices":[{"delta":{"reasoning_content":"Let me think"}}]}',
      'data: {"choices":[{"delta":{"reasoning_content":" about the ledger"}}]}',
      'data: {"choices":[{"delta":{"content":"Your spending"}}]}',
      'data: {"choices":[{"delta":{"content":" is ₹4,200."}}]}',
      'data: [DONE]',
    ];
    expect(AiService.sseDeltas(lines), ['Your spending', ' is ₹4,200.']);
  });

  test('system prompt carries the date and formatting rules, no guardrails', () {
    final prompt = AiService.systemPromptFor('18 August 2026');
    expect(prompt, contains('18 August 2026'));
    expect(prompt, contains('em dashes'));
    expect(prompt, contains('markdown table'));
    // The old "AI's law" guardrails are gone.
    expect(prompt, isNot(contains('Never invent')));
    expect(prompt, isNot(contains('relevant ONLY')));
    expect(prompt, isNot(contains('ignore it entirely')));
  });
}