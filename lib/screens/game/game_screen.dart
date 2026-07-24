import 'package:flutter/material.dart';
import '../../app.dart';
import '../../engine/level_generator.dart';
import '../../engine/simulation_engine.dart';
import '../../models/level.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/sound_paths.dart';
import '../../widgets/level_result_dialog.dart';
import 'level_play_view.dart';

/// Campaign gameplay screen: loads a level by id, hosts the shared
/// [LevelPlayView], and owns progression/reward persistence + the
/// win/lose dialog and retry/next-level flow.
class GameScreen extends StatefulWidget {
  final int levelId;
  const GameScreen({super.key, required this.levelId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late LevelDefinition _level;
  int _attempt = 0;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _level = LevelGenerator.generate(widget.levelId);
    AudioService.instance.playMusic(SoundPaths.gameplaySoundtrack);
  }

  Future<void> _onFinished(SimResult result) async {
    final nextLevelId = (result.won ? widget.levelId + 1 : widget.levelId).clamp(1, LevelGenerator.totalLevels);
    await SaveService.instance.recordLevelResult(levelId: widget.levelId, stars: result.stars, nextLevelId: nextLevelId);
    if (result.won) {
      await SaveService.instance.addResources(
        crystals: 8 * result.stars,
        microParts: 4 * result.stars,
        processors: result.stars == 3 ? 2 : 0,
        xp: (result.score / 8).round(),
      );
    }
    if (!mounted || _dialogShown) return;
    _dialogShown = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelResultDialog(
        result: result,
        hasNextLevel: widget.levelId < LevelGenerator.totalLevels,
        onExit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        onRetry: () {
          Navigator.of(context).pop();
          setState(() {
            _attempt++;
            _dialogShown = false;
          });
        },
        onNext: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => GameScreen(levelId: widget.levelId + 1)),
          );
        },
        onOpenGuide: () => Navigator.of(context).pushNamed(Routes.guide, arguments: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LevelPlayView(
        key: ValueKey(_attempt),
        level: _level,
        onFinished: _onFinished,
        onExit: () => Navigator.of(context).pop(),
      ),
    );
  }
}
