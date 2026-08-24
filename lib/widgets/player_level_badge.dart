import 'package:flutter/material.dart';

import '../services/save_service.dart';
import '../theme/app_colors.dart';

/// Compact player-progression pill shown at the top of the main menu.
///
/// Renders a circular level badge on the left, an animated XP bar in the
/// middle, and a `xp / next` text on the right. Reads directly from
/// [SaveService.instance] — pass a fresh [SaveService] handle from the
/// enclosing `setState` so the bar rebuilds when XP changes.
class PlayerLevelBadge extends StatelessWidget {
  const PlayerLevelBadge({super.key, required this.save});

  final SaveService save;

  @override
  Widget build(BuildContext context) {
    final level = save.playerLevel;
    final progress = save.levelProgress;
    final into = save.xpIntoLevel;
    final span = save.xpForCurrentLevel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gridLine),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _LevelBadge(level: level),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'PLAYER LEVEL',
                      style: TextStyle(
                        color: AppColors.accentCyan.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$into / $span XP',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _XpBar(progress: progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3EEBFF), Color(0xFF128FB8)],
        ),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.6),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Text(
        '$level',
        style: const TextStyle(
          color: Color(0xFF041017),
          fontWeight: FontWeight.w900,
          fontSize: 17,
          height: 1.0,
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * progress;
        return Stack(
          children: [
            Container(
              height: 8,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.boardBase,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.gridLine.withValues(alpha: 0.6),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              height: 8,
              width: fillWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [Color(0xFF34E7FF), Color(0xFFD764F0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.55),
                    blurRadius: 8,
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
