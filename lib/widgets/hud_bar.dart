import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HudBar extends StatelessWidget {
  final int score;
  final int goalScore;
  final int ballsActive;
  final int cascadeLength;
  final double simSpeed;
  final bool simulating;
  final VoidCallback? onSpeedTap;
  final VoidCallback onBack;
  final VoidCallback? onInfo;

  const HudBar({
    super.key,
    required this.score,
    required this.goalScore,
    required this.ballsActive,
    required this.cascadeLength,
    required this.simSpeed,
    required this.simulating,
    required this.onBack,
    this.onSpeedTap,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalScore == 0 ? 1.0 : (score / goalScore).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(color: AppColors.panel.withValues(alpha: 0.92), border: const Border(bottom: BorderSide(color: AppColors.gridLine))),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
              _stat(Icons.bolt, AppColors.accentGold, '$score / $goalScore'),
              const SizedBox(width: 10),
              _stat(Icons.blur_circular, AppColors.accentCyan, '$ballsActive'),
              const SizedBox(width: 10),
              _stat(Icons.auto_awesome, AppColors.accentMagenta, '$cascadeLength'),
              const Spacer(),
              if (onInfo != null)
                IconButton(
                  onPressed: onInfo,
                  tooltip: 'Field Guide',
                  icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
                ),
              if (simulating)
                InkWell(
                  onTap: onSpeedTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.panelLight, borderRadius: BorderRadius.circular(10)),
                    child: Text('${simSpeed.toStringAsFixed(0)}x', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              color: progress >= 1 ? AppColors.success : AppColors.accentCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}
