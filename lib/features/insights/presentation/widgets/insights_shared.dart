import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';

/// Shared presentation helpers for the insights tabs, so every tab speaks the
/// same vocabulary (icons, change lines, month labels).

IconData categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant;
    case 'transport':
      return Icons.directions_car;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'travel':
      return Icons.flight_takeoff;
    case 'subscriptions':
      return Icons.subscriptions_outlined;
    case 'income':
      return Icons.account_balance_wallet_outlined;
    default:
      return Icons.category_outlined;
  }
}

/// One-line comparison of a category's spend vs the prior month, e.g.
/// "↑ 20% vs your usual (₹500)" or "New this month — nothing spent on it
/// last month."
String changeLine(CategorySpend spend, NumberFormat currency) {
  final change = spend.changePercent;
  if (change == null) {
    return 'New this month — nothing spent on it last month.';
  }
  final rounded = change.abs().round();
  final prior = spend.priorAmount ?? 0;
  if (change.abs() < 0.5) {
    return 'About the same as last month (${currency.format(prior)}).';
  }
  final arrow = change > 0 ? '↑' : '↓';
  return '$arrow $rounded% vs your usual (${currency.format(prior)})';
}

/// Lowercase month label for tab headers, e.g. "august 2026".
String monthLabel(int month, int year) {
  return DateFormat('MMMM yyyy')
      .format(DateTime(year, month))
      .toLowerCase();
}
