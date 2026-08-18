import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = [
      {
        'title': 'MacBook Air',
        'current': '₹72,000',
        'target': '₹120,000',
        'progress': 0.60,
        'monthly': '₹8,000 / month',
        'icon': Icons.laptop_mac_rounded,
        'color': RozzColors.accent,
      },
      {
        'title': 'Emergency Fund',
        'current': '₹15,000',
        'target': '₹50,000',
        'progress': 0.30,
        'monthly': '₹5,000 / month',
        'icon': Icons.shield_moon_rounded,
        'color': RozzColors.gold,
      },
      {
        'title': 'Goa Trip 🌴',
        'current': '₹10,000',
        'target': '₹20,000',
        'progress': 0.50,
        'monthly': '₹3,000 / month',
        'icon': Icons.beach_access_rounded,
        'color': RozzColors.income,
      },
    ];

    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'goals',
                      style: GoogleFonts.syne(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: RozzColors.textPrimary,
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: RozzColors.s2,
                        shape: BoxShape.circle,
                        border: Border.all(color: RozzColors.cardBorder),
                      ),
                      child: const Icon(Icons.add, color: RozzColors.gold, size: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Goals List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: goals.map((goal) => _buildGoalCard(goal)).toList(),
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final progress = goal['progress'] as double;
    final pctText = '${(progress * 100).toInt()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (goal['color'] as Color).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(goal['icon'] as IconData, color: goal['color'] as Color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['title'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: RozzColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${goal['current']} / ${goal['target']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: RozzColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                pctText,
                style: GoogleFonts.dmMono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: RozzColors.s3,
              valueColor: AlwaysStoppedAnimation<Color>(goal['color'] as Color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            goal['monthly'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: RozzColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
