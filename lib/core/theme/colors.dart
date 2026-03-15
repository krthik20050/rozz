import 'package:flutter/material.dart';

class RozzColors {
  // Background â€” NEVER pure #000000
  static const bg    = Color(0xFF080810);
  static const s1    = Color(0xFF10101C);  // cards
  static const s2    = Color(0xFF181828);  // sheets
  static const s3    = Color(0xFF202038);  // modals
  static const s4    = Color(0xFF282848);  // overlays

  // Accent â€” actions and focus ONLY, never decorative
  static const accent = Color(0xFF7C6AF7);

  // Semantic â€” never swap these
  static const income  = Color(0xFF1DB954);  // green = income/safe
  static const expense = Color(0xFFE8445A);  // red = expense/danger
  static const insight = Color(0xFFF5C518);  // gold = MAB/insights

  // Text
  static const textPrimary   = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF888898);
}
