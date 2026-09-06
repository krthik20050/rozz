import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/shared/widgets/animated_counter.dart';


class BalanceHero extends StatefulWidget {
  final double balance;

  /// Last 4 digits of the real account number, derived from the bank SMS
  /// ("HDFC Bank •••• 4321"). Null until the migration has seen an SMS.
  final String? accountSuffix;

  /// False when no bank-reported balance exists anywhere in the ledger —
  /// the app then honestly shows "—" (plus a hint) instead of a number
  /// that would be invented from an unknown opening balance.
  final bool bankVerified;

  /// Day (yyyy-MM-dd) of the bank anchor behind [balance]. When it is before
  /// today the hero shows "as of 3 Aug" style freshness — the number was
  /// replayed forward from that bank-reported moment, so its age is visible.
  final String? anchoredOn;

  const BalanceHero({
    super.key,
    required this.balance,
    this.accountSuffix,
    this.bankVerified = false,
    this.anchoredOn,
  });

  @override
  State<BalanceHero> createState() => _BalanceHeroState();
}

class _BalanceHeroState extends State<BalanceHero> {
  bool _isBalanceVisible = true;

  /// Whether the anchor day (yyyy-MM-dd) is today.
  static bool _isToday(String isoDay) {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return isoDay.length >= 10 && isoDay.substring(0, 10) == today;
  }

  static DateTime _anchorDate(String isoDay) {
    final parsed = DateTime.tryParse(isoDay);
    if (parsed != null) return parsed;
    return DateTime.now();
  }

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
                        if (!widget.bankVerified)
                          Text(
                            '—',
                            style: GoogleFonts.dmMono(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: RozzColors.textPrimary,
                            ),
                          )
                        else if (_isBalanceVisible)
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
                        // The eye toggle only means something when a real
                        // number is being shown.
                        if (widget.bankVerified)
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
                      widget.bankVerified
                          ? (widget.accountSuffix == null
                              ? 'available balance  •  HDFC Bank'
                              : 'available balance  •  HDFC Bank •••• ${widget.accountSuffix}')
                          : 'waiting for your first bank SMS to verify balance',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: RozzColors.textSecondary,
                      ),
                    ),
                    // Anchor freshness: the number is replayed forward from
                    // the bank's last reported balance. If that anchor is
                    // older than today, say so — a stale number must never
                    // silently look current.
                    if (widget.bankVerified &&
                        widget.anchoredOn != null &&
                        !_isToday(widget.anchoredOn!))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'as of ${DateFormat('d MMM').format(_anchorDate(widget.anchoredOn!))} — updates with your next bank SMS',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: RozzColors.textSecondary,
                          ),
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
