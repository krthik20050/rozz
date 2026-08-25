import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

/// A calm, dismissible banner shown when the device is rooted/jailbroken.
///
/// Not a hard gate — just a heads-up that the app sandbox is weakened, so
/// anyone with the device can read the on-device data despite encryption.
class SecurityBanner extends StatefulWidget {
  const SecurityBanner({super.key});

  @override
  State<SecurityBanner> createState() => _SecurityBannerState();
}

class _SecurityBannerState extends State<SecurityBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: RozzColors.s2.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RozzColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.security_outlined,
                size: 16, color: RozzColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "this device looks rooted — your data is still encrypted, but the phone's sandbox is weakened.",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RozzColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 14, color: RozzColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}