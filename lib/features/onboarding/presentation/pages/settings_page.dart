import 'package:flutter/material.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _secureStorage = SecureStorageService();
  final _apiKeyController = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  bool _keyExists = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
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
            _buildSectionHeader('AI CATEGORIZATION'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Gemini API Key',
              'Required for automatic transaction categorization and financial insights. '
              'Get a free key from Google AI Studio (aistudio.google.com).',
            ),
            const SizedBox(height: 16),
            _buildApiKeyField(),
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
            _buildSectionHeader('SECURITY'),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Biometric Lock',
              'ROZZ locks automatically after 5 minutes in the background. '
              'Biometric or device PIN is required to re-open.',
            ),
            const SizedBox(height: 32),
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

  Widget _buildApiKeyField() {
    return Container(
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _apiKeyController,
        obscureText: _obscureText,
        style: GoogleFonts.dmMono(fontSize: 14, color: RozzColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'AIza...',
          hintStyle: GoogleFonts.dmMono(color: RozzColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscureText = !_obscureText),
            icon: Icon(
              _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
