import 'dart:async';
import 'dart:convert';
import 'package:flutter_js/flutter_js.dart';

class NodeService {
  static final NodeService _instance = NodeService._internal();
  factory NodeService() => _instance;
  NodeService._internal();

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  late JavascriptRuntime _jsRuntime;

  /// Starts the Engine using flutter_js
  Future<void> startEngine() async {
    try {
      _jsRuntime = getJavascriptRuntime();
      
      // Inject the parsing logic using a raw string for the JS block
      _jsRuntime.evaluate(r"""
        var patterns = {
          amount: /(?:rs|inr)\.?\s?([\d,]+\.?\d*)/i,
          direction: /(?:debited|spent|withdrawn|sent|paid|transfer to)/i,
          recipient: /(?:to|at|vpa)\s?([^.]+?)(?=\s?on\s?|\s?ref\s?|\s?link\s?|\s?is\s?|$)/i,
          balance: /(?:bal|balance|avbl\sbal)\.?\s?(?:is\s?)?(?:rs|inr)\.?\s?([\d,]+\.?\d*)/i,
          upiRef: /(?:ref|rrn)\s?(?:no\.?)?\s?(\d{10,12})/i
        };

        function parseSms(body, sender) {
          try {
            var amountMatch = body.match(patterns.amount);
            var directionMatch = body.match(patterns.direction);
            var recipientMatch = body.match(patterns.recipient);
            var balanceMatch = body.match(patterns.balance);
            var upiMatch = body.match(patterns.upiRef);

            if (amountMatch) {
              return JSON.stringify({
                amount: parseFloat(amountMatch[1].replace(/,/g, '')),
                direction: directionMatch ? 'expense' : 'income',
                recipient: recipientMatch ? recipientMatch[1].trim() : 'Unknown',
                balanceAfter: balanceMatch ? parseFloat(balanceMatch[1].replace(/,/g, '')) : null,        
                upiRef: upiMatch ? upiMatch[1] : null,
                rawSms: body,
                timestamp: new Date().toISOString()
              });
            }
          } catch (e) {
            return JSON.stringify({ error: e.toString() });
          }
          return null;
        }
      """);

      // ignore: avoid_print
      print('NodeService: Engine started successfully via flutter_js.');
    } catch (e) {
      // ignore: avoid_print
      print('NodeService: Failed to start Engine: $e');
      rethrow;
    }
  }

  /// Sends data to the JS bridge
  void sendMessage(String tag, dynamic message) {
    if (tag == 'parse_sms') {
      try {
        final body = message['body'];
        final sender = message['sender'];
        
        final JsEvalResult result = _jsRuntime.evaluate("parseSms(${jsonEncode(body)}, ${jsonEncode(sender)})");
        
        if (result.stringResult != 'null') {
          final decoded = jsonDecode(result.stringResult);
          if (decoded != null && decoded['error'] == null) {
            _messageController.add({
              'tag': 'sms_parsed',
              'message': decoded
            });
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('NodeService: Failed to process JS message: $e');
      }
    }
  }

  void stopEngine() {
    _jsRuntime.dispose();
  }
}
