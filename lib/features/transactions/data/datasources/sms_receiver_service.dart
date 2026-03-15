import 'package:flutter/services.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';

class SmsReceiverService {
  static const MethodChannel _channel = MethodChannel('com.rozz/sms');
  final SmsParser _parser;
  final TransactionLocalDatasource _datasource;

  SmsReceiverService(this._parser, this._datasource);

  void initialize() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<void> _handleMethod(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final Map<dynamic, dynamic> args = call.arguments;
      final String body = args['body'];
      // final String sender = args['sender']; // unused for now
      await _processSms(body);
    }
  }

  Future<void> _processSms(String body) async {
    final parsed = _parser.parse(body);
    if (parsed == null) return;

    final transaction = TransactionModel.fromSms(parsed, body);
    
    // Duplicate detection is handled by ConflictAlgorithm.ignore in datasource
    // because upi_ref_number has a UNIQUE constraint in the DB.
    await _datasource.insertTransaction(transaction);
  }
}
