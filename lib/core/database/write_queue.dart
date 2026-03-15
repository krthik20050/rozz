import 'dart:async';

class WriteQueue {
  Future<void> _lastOperation = Future.value();

  Future<T> add<T>(Future<T> Function() operation) async {
    final Completer<T> completer = Completer<T>();
    
    _lastOperation = _lastOperation.then((_) async {
      try {
        final T result = await operation();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }
}
