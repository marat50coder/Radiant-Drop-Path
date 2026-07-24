import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A neon horizontal progress bar that always fills strictly left to
/// right. [progress] is expected in [0, 1].
class HorizontalProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  const HorizontalProgressBar({super.key, required this.progress, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: AppColors.gridLine, width: 1),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentGold, AppColors.accentCyan],
                ),
                boxShadow: [
                  BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.7), blurRadius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
