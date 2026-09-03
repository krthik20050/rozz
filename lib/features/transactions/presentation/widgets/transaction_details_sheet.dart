import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/resolved_sender.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/insights/presentation/pages/manage_senders_page.dart';
import 'package:rozz/features/merchants/presentation/pages/manage_merchants_page.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';
import 'package:rozz/shared/utils/merchant_key.dart';
import 'package:rozz/shared/utils/sender_label_resolver.dart';

/// Full details for one transaction: parsed fields + the original bank SMS.
class TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailsSheet({super.key, required this.transaction});

  static void show(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TransactionDetailsSheet(transaction: transaction),
    );
  }

  /// Credit senders honor the user's label ("papa") here too, matching the
  /// card and the income tab. Debits show the user's own description first,
  /// then the merchant identity.
  String _displayName(InsightsState state, Transaction tx) {
    final note = tx.userNarration;
    if (note != null && note.trim().isNotEmpty) return note;
    if (tx.direction != 'credit') return tx.recipientName!;
    final labels = state is InsightsLoaded ? state.senderLabels : const <String, String>{};
    final key = (tx.recipientName ?? '').trim().toLowerCase();
    if (key.isEmpty) return tx.recipientName!;
    return resolveSenderLabel(key, labels) ?? tx.recipientName!;
  }

  /// For a debit without a user description the *merchant* display name (brand
  /// name when canonical, else the raw payee) is the detail under the title.
  String _merchantName() {
    final brand = MerchantBrandResolver.resolve(
      transaction.recipientName ?? '',
      transaction.labelType,
      transaction.direction,
    );
    return brand.name;
  }

  String? get _merchantKeyForDebit {
    if (transaction.direction != 'debit') return null;
    final raw = transaction.recipientName ?? '';
    if (raw.trim().isEmpty) return null;
    final brand = MerchantKey.brandCanonicalSlug(raw, transaction.labelType, 'debit');
    return transaction.merchantKey ?? brand ?? MerchantKey.slug(raw);
  }

  String get _merchantCanonicalName {
    final raw = transaction.recipientName ?? '';
    final brandName = _merchantName();
    return brandName.isEmpty ? raw : brandName;
  }

  bool get _canDescribe =>
      transaction.direction == 'debit' &&
      (transaction.recipientName?.trim().isNotEmpty ?? false);

  /// Open the shared payee sheet in per-payment mode: this payment always
  /// adopts the word; the payee's other undecorated payments do too.
  void _describePayment(BuildContext context) {
    final key = _merchantKeyForDebit;
    if (key == null) return;
    showPayeeDescriptionSheet(
      context,
      merchantKey: key,
      canonicalName: _merchantCanonicalName,
      currentDescription: transaction.userNarration,
      paymentsCount: 1,
      merchantWide: false,
      triggerTxId: transaction.id,
      recipientName: transaction.recipientName,
      upiId: transaction.upiId,
      labelType: transaction.labelType,
    );
  }

  /// The raw normalized sender key — used for naming this sender.
  String? get _senderKey {
    if (transaction.direction != 'credit') return null;
    final key = (transaction.recipientName ?? '').trim().toLowerCase();
    return key.isEmpty ? null : key;
  }

  /// "name this sender" / "edit label" — the same frosted sheet as income.
  void _nameSender(BuildContext context) {
    final key = _senderKey;
    if (key == null) return;
    final state = context.read<InsightsBloc>().state;
    final labels = state is InsightsLoaded ? state.senderLabels : const <String, String>{};
    final currentLabel = resolveSenderLabel(key, labels);
    showSenderLabelSheet(
      context,
      ResolvedSender(
        key: key,
        rawName: transaction.recipientName!,
        displayName: currentLabel ?? transaction.recipientName!,
        identified: currentLabel != null,
        identification: currentLabel != null ? 'label' : null,
        amount: transaction.amount,
        count: 1,
      ),
      currentLabel,
    );
  }

  bool _hasLabel(InsightsState state) {
    final key = _senderKey;
    if (key == null) return false;
    final labels = state is InsightsLoaded ? state.senderLabels : const <String, String>{};
    return resolveSenderLabel(key, labels) != null;
  }

  String _directionLabel() {
    switch (transaction.direction) {
      case 'debit':
        return 'Debited';
      case 'credit':
        return 'Credited';
      default:
        return 'Transaction';
    }
  }

  String _formatLabelType(String labelType) {
    switch (labelType) {
      case 'upi':
        return 'UPI Payment';
      case 'atm':
        return 'ATM Withdrawal';
      case 'neft':
        return 'NEFT Transfer';
      case 'imps':
        return 'IMPS Transfer';
      case 'card':
        return 'Card Payment';
      case 'fine':
        return 'MAB Fine';
      default:
        return labelType
            .split('_')
            .map((word) => word.isEmpty
                ? ''
                : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: RozzColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: RozzColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.direction == 'debit';
    final color = isDebit ? RozzColors.expense : RozzColors.income;
    final amount = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(transaction.amount);
    final dateTime = DateTime.parse(transaction.date).toLocal();
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(dateTime);
    final timeStr = DateFormat('hh:mm a').format(dateTime);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: RozzColors.s2.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: RozzColors.cardBorder, width: 1),
            ),
          ),
          child: Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RozzColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _directionLabel(),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.dmMono(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          if (transaction.recipientName != null)
            // Rebuilds when a label/description is saved, so names update live.
            BlocBuilder<InsightsBloc, InsightsState>(
              builder: (context, state) {
                final note = transaction.userNarration;
                final hasNote = note != null && note.trim().isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _displayName(state, transaction),
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: hasNote ? FontWeight.w600 : FontWeight.w400,
                        color: hasNote ? RozzColors.textPrimary : RozzColors.textSecondary,
                      ),
                    ),
                    // The raw merchant identity stays visible under the user's
                    // word — the essence lives together with where it went.
                    if (hasNote && transaction.direction == 'debit') ...[
                      const SizedBox(height: 2),
                      Text(
                        _merchantName(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: RozzColors.textMuted,
                        ),
                      ),
                    ],
                    if (_senderKey != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _nameSender(context),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: _hasLabel(state) ? RozzColors.gold : RozzColors.expense,
                          ),
                          label: Text(
                            _hasLabel(state) ? 'edit label' : 'name this sender',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _hasLabel(state) ? RozzColors.gold : RozzColors.expense,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _hasLabel(state)
                                  ? RozzColors.gold.withValues(alpha: 0.6)
                                  : RozzColors.expense.withValues(alpha: 0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_canDescribe) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _describePayment(context),
                          icon: Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: hasNote ? RozzColors.gold : RozzColors.expense,
                          ),
                          label: Text(
                            hasNote ? 'edit description' : 'describe this payment',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: hasNote ? RozzColors.gold : RozzColors.expense,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: hasNote
                                  ? RozzColors.gold.withValues(alpha: 0.6)
                                  : RozzColors.expense.withValues(alpha: 0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          const SizedBox(height: 24),
          Divider(color: RozzColors.textSecondary.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          _row('Date', dateStr),
          _row('Time', timeStr),
          _row('Type', _formatLabelType(transaction.labelType)),
          if (transaction.category != null) _row('Category', transaction.category!),
          if (transaction.upiRefNumber != null) _row('UPI Ref', transaction.upiRefNumber!),
          if (transaction.upiId != null) _row('UPI ID', transaction.upiId!),
          if (transaction.balanceAfter != null)
            _row('Balance after',
                NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(transaction.balanceAfter!)),
          if (transaction.rawSms != null) ...[
            const SizedBox(height: 16),
            Text(
              'Original SMS',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RozzColors.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RozzColors.s3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                transaction.rawSms!,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  height: 1.5,
                  color: RozzColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
          ),
        ),
      ),
    );
  }
}
