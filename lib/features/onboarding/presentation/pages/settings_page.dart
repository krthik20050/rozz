import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/services/supabase_service.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/sync/sync_service.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _secureStorage = SecureStorageService();

  // Gemini
  final _apiKeyController = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  bool _keyExists = false;

  // Supabase
  final _supabaseUrlController = TextEditingController();
  final _supabaseKeyController = TextEditingController();
  bool _obscureSupabaseKey = true;
  bool _isSavingSupabase = false;
  bool _supabaseConfigured = false;
  bool _isSyncing = false;
  String? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
    _loadSupabaseConfig();
  }

  Future<void> _loadCurrentKey() async {
    try {
      final key = await _secureStorage.readValue('GEMINI_API_KEY');
      if (key != null && key.isNotEmpty) {
        setState(() {
          _keyExists = true;
          _apiKeyController.text = key;
        });
      }
    } catch (e) {
      // Key not yet stored or keystore unavailable — proceed with empty field
      debugPrint('SettingsPage: could not load API key: $e');
    }
  }

  Future<void> _loadSupabaseConfig() async {
    try {
      final url = await _secureStorage.readValue('SUPABASE_URL');
      final key = await _secureStorage.readValue('SUPABASE_ANON_KEY');
      final lastSync = await _secureStorage.readValue('LAST_SYNC_AT');
      if (mounted) {
        setState(() {
          _supabaseConfigured =
              url != null && url.isNotEmpty && key != null && key.isNotEmpty;
          if (url != null) _supabaseUrlController.text = url;
          if (key != null) _supabaseKeyController.text = key;
          _lastSyncAt = lastSync;
        });
      }
    } catch (e) {
      debugPrint('SettingsPage: could not load Supabase config: $e');
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackbar('API key cannot be empty.', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _secureStorage.writeValue('GEMINI_API_KEY', key);
      setState(() => _keyExists = true);
      _showSnackbar('Gemini API key saved ✓');
    } catch (e) {
      _showSnackbar('Failed to save key: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _clearKey() async {
    await _secureStorage.deleteValue('GEMINI_API_KEY');
    _apiKeyController.clear();
    setState(() => _keyExists = false);
    _showSnackbar('API key removed.');
  }

  // ── Supabase ───────────────────────────────────────────────────────────────

  Future<void> _saveSupabaseConfig() async {
    final url = _supabaseUrlController.text.trim();
    final key = _supabaseKeyController.text.trim();
    if (url.isEmpty || key.isEmpty) {
      _showSnackbar('URL and anon key are required.', isError: true);
      return;
    }
    setState(() => _isSavingSupabase = true);
    try {
      await _secureStorage.writeValue('SUPABASE_URL', url);
      await _secureStorage.writeValue('SUPABASE_ANON_KEY', key);
      final ok = await SupabaseService().initialize(url, key);
      if (ok) {
        setState(() => _supabaseConfigured = true);
        _showSnackbar('Supabase connected ✓');
      } else {
        _showSnackbar('Could not connect. Check URL/key.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Save failed: $e', isError: true);
    } finally {
      setState(() => _isSavingSupabase = false);
    }
  }

  Future<void> _clearSupabaseConfig() async {
    await _secureStorage.deleteValue('SUPABASE_URL');
    await _secureStorage.deleteValue('SUPABASE_ANON_KEY');
    _supabaseUrlController.clear();
    _supabaseKeyController.clear();
    setState(() => _supabaseConfigured = false);
    _showSnackbar('Supabase credentials removed.');
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final result = await SyncService().syncAll();
    if (mounted) {
      if (result.success) {
        setState(() => _lastSyncAt = DateTime.now().toUtc().toIso8601String());
        final now = DateTime.now();
        context.read<TransactionBloc>().add(LoadTransactions());
        context.read<MabBloc>().add(LoadMabStatus(
          month: now.month,
          year: now.year,
          now: now,
        ));
        _showSnackbar('Sync complete — ${result.message}');
      } else {
        _showSnackbar(result.message, isError: true);
      }
      setState(() => _isSyncing = false);
    }
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
  void dispose() {
    _apiKeyController.dispose();
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SETTINGS',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AI Categorization ──────────────────────────────────────────
            _buildSectionHeader('AI CATEGORIZATION'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Gemini API Key',
              'Required for automatic transaction categorization and financial insights. '
              'Get a free key from Google AI Studio (aistudio.google.com).',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _apiKeyController,
              obscure: _obscureText,
              hint: 'AIza...',
              onToggleObscure: () =>
                  setState(() => _obscureText = !_obscureText),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: _isSaving ? 'Saving...' : 'Save Key',
                    color: RozzColors.accent,
                    onPressed: _isSaving ? null : _saveKey,
                  ),
                ),
                if (_keyExists) ...[
                  const SizedBox(width: 12),
                  _buildActionButton(
                    label: 'Clear',
                    color: RozzColors.expense,
                    onPressed: _clearKey,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 32),

            // ── Cloud Sync ─────────────────────────────────────────────────
            _buildSectionHeader('CLOUD SYNC'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Supabase Project',
              'Connect your own Supabase project for cross-device sync.\n\n'
              'Run this SQL in your Supabase SQL editor first:\n'
              'create table transactions (id bigserial primary key, device_id text, local_id int, date text, amount real, direction text, label_type text, recipient_name text, upi_id text, balance_after real, source text, upi_ref_number text, category text, unique(device_id, local_id));\n\n'
              'create table mab_history (id bigserial primary key, device_id text, date text, end_of_day_balance real, month int, year int, unique(device_id, date));',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _supabaseUrlController,
              obscure: false,
              hint: 'https://xxxx.supabase.co',
              label: 'Project URL',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _supabaseKeyController,
              obscure: _obscureSupabaseKey,
              hint: 'eyJh...',
              label: 'Anon / Service Key',
              onToggleObscure: () => setState(() => _obscureSupabaseKey = !_obscureSupabaseKey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: _isSavingSupabase ? 'Saving...' : 'Save & Connect',
                    color: RozzColors.accent,
                    onPressed: _isSavingSupabase ? null : _saveSupabaseConfig,
                  ),
                ),
                if (_supabaseConfigured) ...[
                  const SizedBox(width: 12),
                  _buildActionButton(
                    label: 'Clear',
                    color: RozzColors.expense,
                    onPressed: _clearSupabaseConfig,
                  ),
                ],
              ],
            ),
            if (_supabaseConfigured) ...[
              const SizedBox(height: 12),
              _buildActionButton(
                label: _isSyncing ? 'Syncing...' : 'Sync Now',
                color: RozzColors.income,
                onPressed: _isSyncing ? null : _syncNow,
                fullWidth: true,
              ),
              if (_lastSyncAt != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Last synced: ${_formatSyncTime(_lastSyncAt!)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: RozzColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),

            // ── Security ───────────────────────────────────────────────────
            _buildSectionHeader('SECURITY'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Biometric Lock',
              'ROZZ locks automatically after 5 minutes in the background. '
              'Biometric or device PIN is required to re-open.',
            ),
            const SizedBox(height: 32),

            // ── About ──────────────────────────────────────────────────────
            _buildSectionHeader('ABOUT'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'ROZZ v1.0',
              'Your bank balance, finally understood. '
              'HDFC bank SMS messages are parsed locally on-device. '
              'No data is shared with third parties.',
            ),
          ],
        ),
      ),
    );
  }

  String _formatSyncTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
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
    required bool obscure,
    required String hint,
    String? label,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.dmMono(fontSize: 14, color: RozzColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          labelText: label,
          labelStyle: GoogleFonts.dmSans(
            color: RozzColors.textSecondary,
            fontSize: 12,
          ),
          hintStyle: GoogleFonts.dmMono(color: RozzColors.textSecondary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: RozzColors.textSecondary,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool fullWidth = false,
  }) {
    final btn = ElevatedButton(
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
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
