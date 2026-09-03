import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/merchants/domain/entities/merchant.dart';
import 'package:rozz/features/merchants/presentation/bloc/merchant_bloc.dart';

/// Frosted sheet to describe a payee. Shared by the transaction details sheet
/// (per-payment intent, [merchantWide] == false) and the manage-payees page
/// (rename-everywhere intent, [merchantWide] == true).
void showPayeeDescriptionSheet(
  BuildContext context, {
  required String merchantKey,
  required String canonicalName,
  required String? currentDescription,
  required int paymentsCount,
  bool merchantWide = true,
  int? triggerTxId,
  String? recipientName,
  String? upiId,
  String? labelType,
}) {
  final controller = TextEditingController(text: currentDescription ?? '');
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
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
                      merchantWide ? 'what is this payee for?' : 'describe this payment',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: RozzColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canonicalName,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: RozzColors.textSecondary,
                      ),
                    ),
                    if (merchantWide && paymentsCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'applies to $paymentsCount ${paymentsCount == 1 ? 'payment' : 'payments'} of this payee',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: RozzColors.gold,
                        ),
                      ),
                    ],
                    if (!merchantWide) ...[
                      const SizedBox(height: 2),
                      Text(
                        'future payments to the same payee pick this up automatically',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: RozzColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: RozzColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. dinner, rent, treat for mom',
                        hintStyle: const TextStyle(color: RozzColors.textMuted),
                        filled: true,
                        fillColor: RozzColors.s3,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLength: 80,
                    ),
                    Row(
                      children: [
                        if (currentDescription != null && merchantWide) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                context
                                    .read<MerchantBloc>()
                                    .add(ClearMerchantDescription(merchantKey));
                                Navigator.of(sheetContext).pop();
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
                              final value = controller.text.trim();
                              if (value.isNotEmpty) {
                                context.read<MerchantBloc>().add(SaveMerchantDescription(
                                      merchantKey: merchantKey,
                                      canonicalName: canonicalName,
                                      description: value,
                                      merchantWide: merchantWide,
                                      triggerTxId: triggerTxId,
                                      recipientName: recipientName,
                                      upiId: upiId,
                                      labelType: labelType,
                                    ));
                              }
                              Navigator.of(sheetContext).pop();
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

/// Lists every detected payee (merchant). Tap one to describe it — the
/// description applies to every payment of that payee, past and future.
class ManageMerchantsPage extends StatefulWidget {
  const ManageMerchantsPage({super.key});

  @override
  State<ManageMerchantsPage> createState() => _ManageMerchantsPageState();
}

class _ManageMerchantsPageState extends State<ManageMerchantsPage> {
  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Fresh list every open — a merchant may have been created by describing
    // a payment on another screen since the last load.
    context.read<MerchantBloc>().add(LoadMerchants());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'manage payees',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: RozzColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<MerchantBloc, MerchantState>(
          builder: (context, state) {
            if (state is MerchantLoading || state is MerchantInitial) {
              return const Center(
                child: CircularProgressIndicator(color: RozzColors.gold),
              );
            }
            if (state is! MerchantLoaded) {
              return Center(
                child: Text(
                  'couldn\'t load payees',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RozzColors.textSecondary,
                  ),
                ),
              );
            }
            if (state.merchants.isEmpty) {
              return _buildEmpty(context);
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              itemCount: state.merchants.length,
              itemBuilder: (context, index) =>
                  _buildRow(context, state.merchants[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, Merchant merchant) {
    final description = merchant.description;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: merchant.conflict
              ? RozzColors.gold.withValues(alpha: 0.5)
              : RozzColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (description != null ? RozzColors.gold : RozzColors.s2)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              description != null
                  ? Icons.local_offer_outlined
                  : Icons.storefront_outlined,
              color: description != null ? RozzColors.gold : RozzColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.canonicalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description != null ? '“$description”' : 'no description yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: description != null ? RozzColors.gold : RozzColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  merchant.conflict
                      ? 'you described this payee differently before — pick one'
                      : (description != null
                          ? 'your description — auto-applies to every payment'
                          : 'tap to describe this payee'),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: merchant.conflict ? RozzColors.gold : RozzColors.textMuted,
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
                _currency.format(merchant.totalAmount),
                style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
              Text(
                merchant.txCount == 1
                    ? '1 payment'
                    : '${merchant.txCount} payments',
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
            onPressed: () => showPayeeDescriptionSheet(
              context,
              merchantKey: merchant.merchantKey,
              canonicalName: merchant.canonicalName,
              currentDescription: merchant.description,
              paymentsCount: merchant.txCount,
              merchantWide: true,
            ),
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
          const Icon(Icons.storefront_outlined, color: RozzColors.textSecondary, size: 48),
          const SizedBox(height: 16),
          Text(
            'no payees yet',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'merchants and people you pay will show up here — describe one\nand it applies to every payment of theirs.',
            textAlign: TextAlign.center,
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
