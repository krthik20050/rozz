import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

/// A calm, dismissible banner that appears when the device loses connectivity.
///
/// Research: offline states should say *what happened* and reassure, not
/// error out — the app's data lives on-device, so it keeps working offline.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _offline = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final offline = result == ConnectivityResult.none;
      if (mounted && offline != _offline) {
        setState(() {
          _offline = offline;
          if (!offline) _dismissed = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline || _dismissed) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
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
              const Icon(Icons.cloud_off_outlined,
                  size: 16, color: RozzColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "you're offline — your data is safe on your phone",
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
      ),
    );
  }
}
