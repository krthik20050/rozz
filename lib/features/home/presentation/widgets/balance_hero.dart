import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/shared/widgets/animated_counter.dart';


class BalanceHero extends StatefulWidget {
  final double balance;

  /// Last 4 digits of the real account number, derived from the bank SMS
  /// ("HDFC Bank •••• 4736"). Null until the migration has seen an SMS.
  final String? accountSuffix;

  const BalanceHero({
    super.key,
    required this.balance,
    this.accountSuffix,
  });

  @override
  State<BalanceHero> createState() => _BalanceHeroState();
}

class _BalanceHeroState extends State<BalanceHero> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Soft gold glow beneath the panel — gives the frosted blur
        // something to diffuse so the glass reads as glass.
        Positioned(
          top: -40,
          left: -30,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  RozzColors.gold.withValues(alpha: 0.18),
                  RozzColors.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // Translucent so the glow behind diffuses through.
                  color: RozzColors.s2.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: RozzColors.cardBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'good evening,',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: RozzColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Karthik',
                              style: GoogleFonts.syne(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: RozzColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: RozzColors.s2,
                            shape: BoxShape.circle,
                            border: Border.all(color: RozzColors.cardBorder),
                          ),
                          child: const Icon(Icons.person_outline, color: RozzColors.gold, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (_isBalanceVisible)
                          AnimatedCounterText(
                            value: widget.balance,
                            fontSize: 44,
                          )
                        else
                          Text(
                            '••••••••',
                            style: GoogleFonts.dmMono(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: RozzColors.textPrimary,
                            ),
                          ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                          icon: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: RozzColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.accountSuffix == null
                          ? 'available balance  •  HDFC Bank'
                          : 'available balance  •  HDFC Bank •••• ${widget.accountSuffix}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: RozzColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
