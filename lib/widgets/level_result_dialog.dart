import 'package:flutter/material.dart';
import '../engine/simulation_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'neon_button.dart';

class LevelResultDialog extends StatelessWidget {
  final SimResult result;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onExit;
  final bool hasNextLevel;
  final VoidCallback? onOpenGuide;

  const LevelResultDialog({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onNext,
    required this.onExit,
    required this.hasNextLevel,
    this.onOpenGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: AppColors.gridLine)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.won ? 'SCHEME ONLINE' : 'SCHEME FAILED',
              style: titleGlow(size: 22, color: result.won ? AppColors.success : AppColors.danger),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < result.stars;
                return Icon(Icons.star_rounded, size: 40, color: filled ? AppColors.accentGold : AppColors.gridLine);
              }),
            ),
            const SizedBox(height: 18),
            _row('Score', '${result.score}'),
            _row('Delivered', '${result.delivered}'),
            _row('Lost', '${result.lost}'),
            _row('Cascade length', '${result.cascadeCount}'),
            if (!result.won) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panelLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Tip: wiring only the mandatory routers is rarely enough. Fill some optional slots with '
                      'Amplifiers, Resonators or Magnets to push your score higher.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                    ),
                    if (onOpenGuide != null) ...[
                      const SizedBox(height: 10),
                      NeonButton.ghost(
                        label: 'Open Field Guide',
                        icon: Icons.menu_book_outlined,
                        size: NeonButtonSize.small,
                        fullWidth: false,
                        onPressed: onOpenGuide,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: NeonButton.secondary(
                    label: 'Levels',
                    icon: Icons.grid_view_rounded,
                    size: NeonButtonSize.medium,
                    onPressed: onExit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton.ghost(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    size: NeonButtonSize.medium,
                    onPressed: onRetry,
                  ),
                ),
                if (result.won && hasNextLevel) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeonButton.primary(
                      label: 'Next',
                      icon: Icons.arrow_forward_rounded,
                      size: NeonButtonSize.medium,
                      accent: AppColors.success,
                      onPressed: onNext,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
