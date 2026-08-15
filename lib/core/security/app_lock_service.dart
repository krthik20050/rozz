class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  DateTime? _backgroundedAt;
  bool _isLocked = true;

  final Duration _lockTimeout = const Duration(minutes: 5);

  bool get isLocked => _isLocked;

  void onAppBackground() {
    _backgroundedAt = DateTime.now();
  }

  void onAppForeground() {
    if (_backgroundedAt != null) {
      final difference = DateTime.now().difference(_backgroundedAt!);
      if (difference > _lockTimeout) {
        _isLocked = true;
      }
      _backgroundedAt = null;
    }
  }

  void unlock() {
    _isLocked = false;
    _backgroundedAt = null;
  }

  void lock() {
    _isLocked = true;
  }
}