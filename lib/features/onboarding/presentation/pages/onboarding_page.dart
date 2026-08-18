import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

/// First-run walkthrough (3 screens):
/// 1. value promise — what ROZZ does for you
/// 2. privacy — everything stays on your phone (the trust point)
/// 3. preview — shows the app shape and explains the ONE permission it asks,
///    with the *why* line, before the real permission request fires.
///
/// Research: value-first, progressive, skip-able, and every permission gets a
/// reason. Fintech onboarding that explains permissions converts far better
/// than one that just asks.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      HapticFeedback.selectionClick();
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onDone();
    }
  }

  void _skip() {
    HapticFeedback.selectionClick();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 20, 0),
                child: TextButton(
                  onPressed: _page < 2 ? _skip : null,
                  child: Text(
                    'skip',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: RozzColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  _ValuePage(),
                  _PrivacyPage(),
                  _PreviewPage(),
                ],
              ),
            ),
            // Dots + primary CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? RozzColors.gold : RozzColors.s3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RozzColors.gold,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        _page < 2 ? 'continue' : 'get started',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String>? bullets;
  final Widget? extra;

  const _PageShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.bullets,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  RozzColors.gold.withValues(alpha: 0.28),
                  RozzColors.gold.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: RozzColors.s2,
                  shape: BoxShape.circle,
                  border: Border.all(color: RozzColors.cardBorder),
                ),
                child: Icon(icon, color: RozzColors.gold, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.5,
              color: RozzColors.textSecondary,
            ),
          ),
          if (bullets != null) ...[
            const SizedBox(height: 28),
            for (final bullet in bullets!) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: RozzColors.income),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        bullet,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: RozzColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (extra != null) ...[
            const SizedBox(height: 28),
            extra!,
          ],
        ],
      ),
    );
  }
}

class _ValuePage extends StatelessWidget {
  const _ValuePage();

  @override
  Widget build(BuildContext context) {
    return const _PageShell(
      icon: Icons.account_balance_wallet_rounded,
      title: 'your bank balance,\nfinally understood.',
      subtitle:
          'ROZZ reads your bank SMS and turns them into a living picture — '
          'balance, spending, subscriptions and money in, all in one place.',
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return const _PageShell(
      icon: Icons.shield_outlined,
      title: 'nothing leaves\nyour phone.',
      subtitle:
          'ROZZ works entirely on your device — no account logins, no servers, '
          'no data uploaded. Your money history stays yours.',
      bullets: [
        'bank SMS read on-device',
        'no bank login, ever',
        'no data uploaded — everything stays local',
      ],
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage();

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      icon: Icons.auto_awesome_rounded,
      title: 'see your money\ncome alive.',
      subtitle:
          'One permission to start: ROZZ reads your bank SMS so it can show '
          'your transactions — and it explains what it finds.',
      extra: Column(
        children: [
          // A mini preview of the app: balance card + a couple of rows.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RozzColors.s1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RozzColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'available balance',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: RozzColors.textSecondary,
                      ),
                    ),
                    const Icon(Icons.visibility_outlined,
                        size: 14, color: RozzColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹ 24,560',
                      style: GoogleFonts.dmMono(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: RozzColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '+ ₹ 8,000 this month',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: RozzColors.income,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: RozzColors.s1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RozzColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: RozzColors.gold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 16, color: RozzColors.gold),
                ),
                const SizedBox(width: 12),
                Text(
                  'father sent you ₹ 5,000',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: RozzColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
