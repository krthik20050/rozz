import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/statement_upload/presentation/bloc/statement_sync_bloc.dart';

/// Statement Sync settings: server URL + API key + "Sync now".
///
/// Flow: the user messages their ROZZ WhatsApp business number with a bank
/// statement PDF → the statement server parses/categorizes it (redacted) →
/// the app pulls the rows here and ingests them into the ledger.
class StatementSyncPage extends StatefulWidget {
  const StatementSyncPage({super.key});

  @override
  State<StatementSyncPage> createState() => _StatementSyncPageState();
}

class _StatementSyncPageState extends State<StatementSyncPage> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    context.read<StatementSyncBloc>().add(const StatementSyncLoad());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _syncNow() {
    context.read<StatementSyncBloc>().add(const StatementSyncRequested());
  }

  void _save() {
    context.read<StatementSyncBloc>().add(StatementSyncSaveConfig(
          serverUrl: _urlController.text,
          apiKey: _apiKeyController.text,
        ));
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        backgroundColor: isError ? RozzColors.expense : RozzColors.income,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'STATEMENT SYNC',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: RozzColors.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: RozzColors.textSecondary),
      ),
      body: BlocConsumer<StatementSyncBloc, StatementSyncState>(
        listener: (context, state) {
          if (state is StatementSyncError) {
            _showSnackbar(state.message, isError: true);
          }
          if (state is StatementSyncReady && state.result != null) {
            final r = state.result!;
            _showSnackbar(
              'Synced: ${r.inserted} new, ${r.duplicates} already known.',
            );
          }
          if (state is StatementSyncReady && !_loaded) {
            _urlController.text = state.config.serverUrl;
            _apiKeyController.clear();
            _loaded = true;
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  'How it works',
                  'Send your bank statement PDF to your ROZZ WhatsApp number. '
                  'The server parses and categorizes it (PII redacted, media '
                  'deleted after processing) and ROZZ pulls the rows here. '
                  'Setup steps live in statement_server/README.md.',
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('SERVER'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _urlController,
                  hint: 'https://your-server.example.com',
                  obscure: false,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('API KEY'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _apiKeyController,
                  hint: 'Bearer key the server generated',
                  obscure: _obscureKey,
                  obscureToggle: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'Save',
                        color: RozzColors.accent,
                        onPressed: _save,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: state is StatementSyncSyncing
                            ? 'Syncing…'
                            : 'Sync now',
                        color: RozzColors.gold,
                        onPressed:
                            state is StatementSyncSyncing ? null : _syncNow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildStatusCard(state),
                const SizedBox(height: 24),
                _buildInfoCard(
                  'Privacy',
                  'Statements are redacted on the server before storage: '
                  'account numbers, IFSC, phones, UPI ids and refs are '
                  'scrubbed from narrations. The raw PDF is never stored and '
                  'is deleted from Meta after processing. Rows land in your '
                  'encrypted on-device database like any SMS.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(StatementSyncState state) {
    if (state is StatementSyncSyncing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RozzColors.s1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: RozzColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Pulling rows from the server…',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: RozzColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    if (state is StatementSyncReady) {
      final result = state.result;
      final lastSync = state.config.lastSync;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RozzColors.s1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LAST SYNC',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: RozzColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lastSync == null
                  ? 'Never — the server has nothing pulled yet.'
                  : DateFormat('d MMM yyyy, h:mm a').format(lastSync.toLocal()),
              style: GoogleFonts.dmMono(
                fontSize: 13,
                color: RozzColors.textPrimary,
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Text(
                '${result.inserted} new · ${result.duplicates} already known · '
                '${result.fetched} fetched',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: RozzColors.income,
                ),
              ),
            ],
            if (state.config.apiKeySet) ...[
              const SizedBox(height: 12),
              Text(
                'API key saved ✓',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RozzColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: RozzColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInfoCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: RozzColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    VoidCallback? obscureToggle,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.dmMono(fontSize: 14, color: RozzColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmMono(color: RozzColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          suffixIcon: obscureToggle == null
              ? null
              : IconButton(
                  onPressed: obscureToggle,
                  icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: RozzColors.textSecondary,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
    );
  }
}