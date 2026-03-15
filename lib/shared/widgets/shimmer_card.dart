import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 72,
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Opacity(
        opacity: 0.1,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const CircleAvatar(backgroundColor: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 100, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 150, color: Colors.white),
                ],
              ),
            ),
            Container(height: 12, width: 60, color: Colors.white),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
