import 'package:flutter/material.dart';
import '../../app.dart';
import '../../engine/level_generator.dart';
import '../../engine/simulation_engine.dart';
import '../../models/level.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/sound_paths.dart';
import '../../widgets/level_result_dialog.dart';
import '../../widgets/neon_button.dart';
import '../game/level_play_view.dart';

/// Endless mode: an unbounded sequence of procedurally generated boards
/// of ever-increasing size and difficulty. The run ends the first time a
/// scheme fails to meet its goal; the cumulative score across all
/// completed rounds is compared against the player's personal best.
class EndlessScreen extends StatefulWidget {
  const EndlessScreen({super.key});

  @override
  State<EndlessScreen> createState() => _EndlessScreenState();
}

class _EndlessScreenState extends State<EndlessScreen> {
  int _round = 1;
  int _cumulativeScore = 0;
  late LevelDefinition _level;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _level = LevelGenerator.generateEndlessRound(_round);
    AudioService.instance.playMusic(SoundPaths.endlessSoundtrack);
  }

  Future<void> _onFinished(SimResult result) async {
    if (result.won) _cumulativeScore += result.score;
    if (!mounted || _dialogShown) return;
    _dialogShown = true;
    if (result.won) {
      await SaveService.instance.addResources(
        crystals: 3 + _round,
        microParts: 2,
        xp: (result.score / 10).round(),
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => LevelResultDialog(
          result: result,
          hasNextLevel: true,
          onExit: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          onRetry: () {
            Navigator.of(context).pop();
            setState(() => _dialogShown = false);
          },
          onNext: () {
            Navigator.of(context).pop();
            setState(() {
              _round++;
              _level = LevelGenerator.generateEndlessRound(_round);
              _dialogShown = false;
            });
          },
        ),
      );
    } else {
      await SaveService.instance.setBestEndlessScore(_cumulativeScore);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _EndlessGameOverDialog(
          round: _round,
          cumulativeScore: _cumulativeScore,
          isNewBest: _cumulativeScore >= SaveService.instance.bestEndlessScore,
          onRestart: () {
            Navigator.of(context).pop();
            setState(() {
              _round = 1;
              _cumulativeScore = 0;
              _level = LevelGenerator.generateEndlessRound(_round);
              _dialogShown = false;
            });
          },
          onExit: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          onOpenGuide: () => Navigator.of(context).pushNamed(Routes.guide, arguments: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: AppColors.panelLight,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'ENDLESS · ROUND $_round · TOTAL $_cumulativeScore',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: LevelPlayView(
              key: ValueKey('$_round-$_dialogShown'),
              level: _level,
              onFinished: _onFinished,
              onExit: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndlessGameOverDialog extends StatelessWidget {
  final int round;
  final int cumulativeScore;
  final bool isNewBest;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback? onOpenGuide;

  const _EndlessGameOverDialog({
    required this.round,
    required this.cumulativeScore,
    required this.isNewBest,
    required this.onRestart,
    required this.onExit,
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
            Text('RUN OVER', style: titleGlow(size: 22, color: AppColors.danger)),
            const SizedBox(height: 10),
            Text('Reached round $round', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('$cumulativeScore', style: titleGlow(size: 34, color: AppColors.accentGold)),
            const Text('total flux score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            if (isNewBest) ...[
              const SizedBox(height: 8),
              const Text('NEW BEST!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
            ],
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: NeonButton.secondary(
                    label: 'Exit',
                    icon: Icons.exit_to_app_rounded,
                    size: NeonButtonSize.medium,
                    onPressed: onExit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton.primary(
                    label: 'Restart',
                    icon: Icons.replay_rounded,
                    size: NeonButtonSize.medium,
                    onPressed: onRestart,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
