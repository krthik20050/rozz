import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';

class ErrorState extends StatelessWidget {
  final String message;
  const ErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RozzColors.expense),
      ),
      child: Text(
        message,
        style: const TextStyle(color: RozzColors.expense),
      ),
    );
  }
}

