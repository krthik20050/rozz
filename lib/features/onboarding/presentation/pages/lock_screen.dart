import 'package:flutter/material.dart';
import 'package:rozz/core/security/biometric_service.dart';
import 'package:rozz/core/security/app_lock_service.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const LockScreen({super.key, required this.onAuthenticated});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _biometricService = BiometricService();
  final _appLockService = AppLockService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    final success = await _biometricService.authenticate();
    if (success) {
      _appLockService.unlock();
      widget.onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ROZZ',
              style: GoogleFonts.syne(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: RozzColors.textPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            IconButton(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint, size: 48, color: RozzColors.accent),
              tooltip: 'Retry Authentication',
            ),
          ],
        ),
      ),
    );
  }
}
