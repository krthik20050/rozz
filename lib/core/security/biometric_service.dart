import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return true; // No biometric/security - allow through as per requirement

      return await _auth.authenticate(
        localizedReason: 'Verify it is you to open ROZZ',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN fallback
        ),
      );
    } catch (e) {
      // logError('Biometric failed', e);
      return false;
    }
  }
}
