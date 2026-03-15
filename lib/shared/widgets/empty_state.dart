import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox_outlined, size: 48, color: RozzColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(color: RozzColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
