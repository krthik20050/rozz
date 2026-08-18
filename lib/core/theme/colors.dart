import 'package:flutter/material.dart';

class RozzColors {
  // Background & Surfaces
  static const bg    = Color(0xFF0A0A0E);
  static const s1    = Color(0xFF12121A);  // Cards / Containers
  static const s2    = Color(0xFF1A1A26);  // Sheets / Sub-cards
  static const s3    = Color(0xFF222232);  // Modals / Elevated
  static const s4    = Color(0xFF2A2A3E);  // Overlays / Highlights

  // Accent Colors
  static const accent     = Color(0xFF7C6AF7); // Indigo Violet
  static const gold       = Color(0xFFE5A93C); // Warm Gold Accent / MAB
  static const goldLight  = Color(0xFFF0C265);

  // Semantic Colors
  static const income  = Color(0xFF1DB954);  // Green = Income / Safe
  static const expense = Color(0xFFE8445A);  // Red = Expense / Danger
  static const insight = Color(0xFFE5A93C);  // Gold = MAB / Insights

  // Text
  static const textPrimary   = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF888898);
  static const textMuted     = Color(0xFF555566);

  // Borders & Glows
  static const cardBorder = Color(0x1AFFFFFF); // 10% White border
  static const goldGlow   = Color(0x33E5A93C); // 20% Gold glow
  static const accentGlow = Color(0x337C6AF7); // 20% Violet glow

  // Gradients
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF0C265), Color(0xFFE5A93C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkCardGradient = LinearGradient(
    colors: [Color(0xFF161622), Color(0xFF101018)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
