import 'package:flutter/material.dart';
import '../../app.dart';
import '../../engine/level_generator.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/asset_paths.dart';
import '../../utils/sound_paths.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Campaign'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Field Guide',
            onPressed: () => Navigator.of(context).pushNamed(Routes.guide),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AssetPaths.chapterBackground(2), fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: LevelGenerator.chapterCount,
            itemBuilder: (context, chapter) {
              final firstLevel = chapter * LevelGenerator.levelsPerChapter + 1;
              final lastLevel = firstLevel + LevelGenerator.levelsPerChapter - 1;
              final chapterUnlocked = save.highestUnlockedLevel >= firstLevel;
              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.panel.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.gridLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chapterUnlocked ? AppColors.accentCyan : AppColors.gridLine,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${chapter + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF041017))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(LevelGenerator.chapterName(chapter),
                              style: titleGlow(size: 18, color: chapterUnlocked ? AppColors.accentCyan : AppColors.textSecondary)),
                        ),
                        if (!chapterUnlocked) const Icon(Icons.lock, color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var id = firstLevel; id <= lastLevel; id++)
                          _LevelButton(levelId: id, unlocked: save.highestUnlockedLevel >= id),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelButton extends StatefulWidget {
  final int levelId;
  final bool unlocked;
  const _LevelButton({required this.levelId, required this.unlocked});

  @override
  State<_LevelButton> createState() => _LevelButtonState();
}

class _LevelButtonState extends State<_LevelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final stars = SaveService.instance.levelStars[widget.levelId] ?? 0;
    final unlocked = widget.unlocked;
    final completed = stars > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: unlocked ? (_) => setState(() => _pressed = true) : null,
      onTapUp: unlocked ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: unlocked ? () => setState(() => _pressed = false) : null,
      onTap: unlocked
          ? () {
              AudioService.instance.playSfx(SoundPaths.buttonClick);
              Navigator.of(context).pushNamed(Routes.game, arguments: widget.levelId);
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 62,
          height: 68,
          decoration: BoxDecoration(
            gradient: completed
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentCyan.withValues(alpha: 0.28), AppColors.accentMagenta.withValues(alpha: 0.22)],
                  )
                : null,
            color: completed ? null : (unlocked ? AppColors.panelLight : Colors.black.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unlocked ? AppColors.accentCyan.withValues(alpha: completed ? 0.9 : 0.6) : AppColors.gridLine,
              width: completed ? 1.6 : 1,
            ),
            boxShadow: unlocked && !_pressed
                ? [BoxShadow(color: AppColors.accentCyan.withValues(alpha: completed ? 0.35 : 0.15), blurRadius: 12, offset: const Offset(0, 4))]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (unlocked)
                Text('${widget.levelId}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary))
              else
                const Icon(Icons.lock, size: 18, color: AppColors.textSecondary),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: i < stars ? AppColors.accentGold : AppColors.gridLine,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
