import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/resolved_sender.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/shared/widgets/animated_check.dart';

/// Frosted bottom sheet to name a sender ("father"), edit, or remove the label.
/// Shared by the manage-senders screen and the income tab's "who is this?"
/// prompt, so both flows feel identical.
void showSenderLabelSheet(
  BuildContext context,
  ResolvedSender sender,
  String? currentLabel,
) {
  final controller = TextEditingController(text: currentLabel ?? '');
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Full-height scroll so the keyboard never overflows the sheet (the
    // "bottom overflowed by X pixels" error on small screens).
    isScrollControlled: true,
    builder: (sheetContext) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: RozzColors.s2.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: RozzColors.cardBorder, width: 1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'name this sender',
                    style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: RozzColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sender.key,
                    style: GoogleFonts.dmMono(
                      fontSize: 12,
                      color: RozzColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: RozzColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. father',
                      hintStyle: const TextStyle(color: RozzColors.textMuted),
                      filled: true,
                      fillColor: RozzColors.s3,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (currentLabel != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              context
                                  .read<InsightsBloc>()
                                  .add(DeleteSenderLabel(key: sender.key));
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: RozzColors.s2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    content: Text(
                                      'label removed',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: RozzColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: RozzColors.expense,
                              side: const BorderSide(color: RozzColors.expense),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('remove'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final label = controller.text.trim();
                            if (label.isNotEmpty) {
                              context
                                  .read<InsightsBloc>()
                                  .add(SaveSenderLabel(key: sender.key, label: label));
                            }
                            Navigator.of(sheetContext).pop();
                            if (label.isNotEmpty) {
                              // Success micro-interaction: a springy green
                              // check in a brief confirmation toast.
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: RozzColors.s2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    content: Row(
                                      children: [
                                        const AnimatedCheck(),
                                        const SizedBox(width: 10),
                                        Text(
                                          "saved as '$label'",
                                          style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: RozzColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RozzColors.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Lists every detected money sender from real transactions. Tap a sender to
/// name it ("father"), edit the label, or remove it. Labels persist and the
/// income tab groups by them.
class ManageSendersPage extends StatelessWidget {
  const ManageSendersPage({super.key});

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'manage senders',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: RozzColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<InsightsBloc, InsightsState>(
          builder: (context, state) {
            if (state is! InsightsLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: RozzColors.gold),
              );
            }
            if (state.senders.isEmpty) {
              return _buildEmpty(context);
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              itemCount: state.senders.length,
              itemBuilder: (context, index) {
                final sender = state.senders[index];
                final label = state.senderLabels[sender.key];
                return _buildSenderRow(context, sender, label);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSenderRow(BuildContext context, ResolvedSender sender, String? label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (label != null ? RozzColors.income : RozzColors.s2)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              label != null ? Icons.person_outline : Icons.help_outline,
              color: label != null ? RozzColors.income : RozzColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ?? sender.rawName,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sender.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    color: RozzColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  switch (sender.identification) {
                    'label' => 'named by you',
                    'contact' => 'matched from your contacts',
                    _ => 'from SMS — tap to name',
                  },
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: sender.identification == null
                        ? RozzColors.textMuted
                        : RozzColors.income,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currency.format(sender.amount),
                style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
              Text(
                sender.count == 1 ? '1 payment' : '${sender.count} payments',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: RozzColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: RozzColors.gold, size: 18),
            onPressed: () => showSenderLabelSheet(context, sender, label),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, color: RozzColors.textSecondary, size: 48),
          const SizedBox(height: 16),
          Text(
            'no senders yet',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'people who send you money will show up here.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: RozzColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
