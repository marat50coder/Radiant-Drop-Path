import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../app.dart';
import '../../engine/simulation_engine.dart';
import '../../models/ball_color.dart';
import '../../models/component_type.dart';
import '../../models/grid_models.dart';
import '../../models/level.dart';
import '../../models/placed_component.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/asset_paths.dart';
import '../../utils/sound_paths.dart';
import '../../widgets/board_view.dart';
import '../../widgets/component_palette.dart';
import '../../widgets/hud_bar.dart';
import '../../widgets/neon_button.dart';

enum GamePhase { design, simulating, finished }

/// Shared "design a scheme, then launch it" gameplay surface used by both
/// the campaign [GameScreen] and Endless mode. Give it a fresh [Key] (e.g.
/// keyed by attempt/round number) to force a clean restart.
class LevelPlayView extends StatefulWidget {
  final LevelDefinition level;
  final void Function(SimResult result) onFinished;
  final VoidCallback onExit;

  const LevelPlayView({
    super.key,
    required this.level,
    required this.onFinished,
    required this.onExit,
  });

  @override
  State<LevelPlayView> createState() => LevelPlayViewState();
}

class LevelPlayViewState extends State<LevelPlayView> with TickerProviderStateMixin {
  final Map<String, PlacedComponent> _placements = {};
  late Map<ComponentType, int> _remaining;
  ComponentType? _selectedType;
  GamePhase _phase = GamePhase.design;

  SimulationEngine? _engine;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  double _accumulatorMs = 0;
  double _simSpeed = 1;
  static const double _tickMs = 200;

  final Set<String> _flashingNodes = {};
  List<BallRenderInfo> _ballsRender = [];
  bool _finishedCallbackSent = false;

  LevelDefinition get level => widget.level;

  @override
  void initState() {
    super.initState();
    _remaining = Map<ComponentType, int>.from(level.inventory);
    _simSpeed = SaveService.instance.defaultSimSpeed.clamp(1, 4);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  bool get _readyToLaunch => level.mandatorySlots.keys.every((k) => _placements.containsKey(k));

  void _onSelectPaletteType(ComponentType type) {
    AudioService.instance.playSfx(SoundPaths.buttonHover, volume: 0.5);
    setState(() => _selectedType = _selectedType == type ? null : type);
  }

  void _openGuide([int tab = 1]) {
    AudioService.instance.playSfx(SoundPaths.buttonClick, volume: 0.6);
    Navigator.of(context).pushNamed(Routes.guide, arguments: tab);
  }

  void _showComponentInfo(ComponentType type) {
    AudioService.instance.playSfx(SoundPaths.buttonHover, volume: 0.5);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.panelLight, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset(AssetPaths.componentIcon(type, 0), fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(type.displayName, style: titleGlow(size: 18))),
                ],
              ),
              const SizedBox(height: 10),
              Text(type.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35)),
              const SizedBox(height: 12),
              for (final line in type.mechanics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4, right: 8),
                        child: Icon(Icons.bolt, size: 13, color: AppColors.accentCyan),
                      ),
                      Expanded(
                        child: Text(line, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _onSlotTap(String nodeKey) {
    if (_phase != GamePhase.design) return;
    final node = level.nodes[nodeKey];
    if (node == null) return;

    if (_placements.containsKey(nodeKey)) {
      final removed = _placements.remove(nodeKey)!;
      setState(() => _remaining[removed.type] = (_remaining[removed.type] ?? 0) + 1);
      AudioService.instance.playSfx(SoundPaths.buttonClick, volume: 0.6);
      return;
    }

    final type = _selectedType;
    if (type == null) return;
    if ((_remaining[type] ?? 0) <= 0) return;

    if (node.kind == NodeKind.mandatoryRouter) {
      final required = level.mandatorySlots[nodeKey];
      if (type != required) return;
    } else if (node.kind != NodeKind.optionalSlot) {
      return;
    }

    final placement = PlacedComponent(
      nodeKey: nodeKey,
      type: type,
      skinIndex: SaveService.instance.skinFor(type),
      targetColor: type.needsColorConfig ? level.allowedColors.first : null,
      delayTicks: 4,
    );
    setState(() {
      _placements[nodeKey] = placement;
      _remaining[type] = (_remaining[type] ?? 1) - 1;
    });
    AudioService.instance.playSfx(SoundPaths.buttonClick);

    if (type.needsColorConfig || type.needsDelayConfig) {
      _showConfigSheet(nodeKey, placement);
    }
  }

  void _showConfigSheet(String nodeKey, PlacedComponent placement) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: placement.type.needsColorConfig
              ? _ColorPicker(
                  allowed: level.allowedColors.toList(),
                  selected: placement.targetColor ?? level.allowedColors.first,
                  onPicked: (c) {
                    setState(() => _placements[nodeKey] = placement.copyWith(targetColor: c));
                    Navigator.pop(context);
                  },
                )
              : _DelayStepper(
                  value: placement.delayTicks,
                  onChanged: (v) => setState(() => _placements[nodeKey] = placement.copyWith(delayTicks: v)),
                  onDone: () => Navigator.pop(context),
                ),
        );
      },
    );
  }

  void launch() {
    if (!_readyToLaunch || _phase != GamePhase.design) return;
    AudioService.instance.playSfx(SoundPaths.activationScheme);
    _engine = SimulationEngine(level: level, placements: _placements);
    setState(() => _phase = GamePhase.simulating);
    _accumulatorMs = 0;
    _lastElapsed = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final deltaMs = (elapsed - _lastElapsed).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;
    _accumulatorMs += deltaMs * _simSpeed;

    final engine = _engine;
    if (engine == null) return;
    while (_accumulatorMs >= _tickMs) {
      _accumulatorMs -= _tickMs;
      final keepGoing = engine.step();
      _consumeEvents(engine);
      if (!keepGoing) break;
    }
    _rebuildBallRenderList(engine, _accumulatorMs / _tickMs);
    if (engine.isComplete && _phase == GamePhase.simulating) {
      _finishSimulation(engine);
    }
  }

  void _consumeEvents(SimulationEngine engine) {
    final events = engine.drainEvents();
    for (final e in events) {
      switch (e.type) {
        case SimEventType.activate:
          _flashingNodes.add(e.pos.key);
          Future.delayed(const Duration(milliseconds: 220), () {
            if (mounted) setState(() => _flashingNodes.remove(e.pos.key));
          });
          _sfxForComponent(e.component);
          break;
        case SimEventType.delivered:
          AudioService.instance.playSfx(SoundPaths.ballHitsReceiver, volume: 0.7);
          break;
        case SimEventType.resonance:
          AudioService.instance.playSfx(SoundPaths.resonanceActivation);
          break;
        case SimEventType.generatorAwake:
        case SimEventType.generatorSpawn:
          AudioService.instance.playSfx(SoundPaths.energyGeneration, volume: 0.6);
          break;
        case SimEventType.lost:
        case SimEventType.spawn:
          break;
      }
    }
  }

  void _sfxForComponent(ComponentType? type) {
    if (type == null) return;
    switch (type) {
      case ComponentType.amplifier:
        AudioService.instance.playSfx(SoundPaths.signalAmplifierActivation, volume: 0.5);
        break;
      case ComponentType.divider:
        AudioService.instance.playSfx(SoundPaths.splitActivation, volume: 0.5);
        break;
      case ComponentType.colorConverter:
        AudioService.instance.playSfx(SoundPaths.colorTransformation, volume: 0.5);
        break;
      case ComponentType.delay:
        AudioService.instance.playSfx(SoundPaths.energyPause, volume: 0.4);
        break;
      case ComponentType.intersection:
        AudioService.instance.playSfx(SoundPaths.crossroadSwitching, volume: 0.4);
        break;
      case ComponentType.accelerator:
        AudioService.instance.playSfx(SoundPaths.accelerationActivation, volume: 0.5);
        break;
      case ComponentType.teleport:
        AudioService.instance.playSfx(SoundPaths.teleportation, volume: 0.6);
        break;
      case ComponentType.magnet:
        AudioService.instance.playSfx(SoundPaths.magneticAttraction, volume: 0.5);
        break;
      case ComponentType.resonator:
      case ComponentType.generator:
        break;
    }
  }

  void _rebuildBallRenderList(SimulationEngine engine, double subTick) {
    final list = <BallRenderInfo>[];
    for (final ball in engine.balls) {
      if (!ball.alive) continue;
      final clampedSub = subTick.clamp(0.0, 1.0).toDouble();
      final rawFraction = (ball.hopProgress + clampedSub) / ball.ticksPerHop;
      final fraction = rawFraction.clamp(0.0, 1.0).toDouble();
      final from = Offset(ball.fromNode.col.toDouble(), ball.fromNode.row.toDouble());
      final to = Offset(ball.toNode.col.toDouble(), ball.toNode.row.toDouble());
      final pos = Offset.lerp(from, to, fraction)! + const Offset(0.5, 0.5);
      list.add(BallRenderInfo(position: pos, color: ball.color.color, iconAsset: AssetPaths.ballIcon(ball.color)));
    }
    setState(() => _ballsRender = list);
  }

  void _finishSimulation(SimulationEngine engine) {
    _ticker?.stop();
    final result = engine.result;
    if (result == null) return;
    setState(() {
      _phase = GamePhase.finished;
      _ballsRender = [];
    });
    if (result.won) {
      AudioService.instance.playSfx(SoundPaths.missionCompleted);
    } else {
      AudioService.instance.playSfx(SoundPaths.failureJingle);
    }
    if (!_finishedCallbackSent) {
      _finishedCallbackSent = true;
      widget.onFinished(result);
    }
  }

  void skipToEnd() {
    final engine = _engine;
    if (engine == null) return;
    _ticker?.stop();
    engine.runToCompletion();
    _finishSimulation(engine);
  }

  void _cycleSpeed() {
    setState(() => _simSpeed = _simSpeed >= 4 ? 1 : _simSpeed * 2);
  }

  @override
  Widget build(BuildContext context) {
    final score = _phase == GamePhase.design ? 0 : (_engine?.score ?? 0);
    final cascade = _phase == GamePhase.design ? 0 : (_engine?.cascadeCount ?? 0);
    final activeBalls = _engine?.balls.where((b) => b.alive).length ?? 0;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: HudBar(
            score: score,
            goalScore: level.goal.minScore,
            ballsActive: activeBalls,
            cascadeLength: cascade,
            simSpeed: _simSpeed,
            simulating: _phase == GamePhase.simulating,
            onBack: widget.onExit,
            onSpeedTap: _cycleSpeed,
            onInfo: () => _openGuide(1),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(AssetPaths.chapterBackground(level.backgroundIndex), fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.55)),
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final byWidth = constraints.maxWidth / level.cols;
                    final byHeight = constraints.maxHeight / level.rows;
                    final cellSize = (byWidth < byHeight ? byWidth : byHeight).clamp(24.0, 64.0).toDouble();
                    return BoardView(
                      level: level,
                      placements: _placements,
                      cellSize: cellSize,
                      balls: _ballsRender,
                      flashingNodes: _flashingNodes,
                      onSlotTap: _onSlotTap,
                    );
                  }),
                ),
              ),
              if (_phase == GamePhase.simulating)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.accentMagenta,
                    onPressed: skipToEnd,
                    child: const Icon(Icons.fast_forward),
                  ),
                ),
            ],
          ),
        ),
        if (_phase == GamePhase.design)
          Container(
            decoration: const BoxDecoration(color: AppColors.panel, border: Border(top: BorderSide(color: AppColors.gridLine))),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ComponentPalette(
                    remaining: _remaining,
                    selected: _selectedType,
                    onSelect: _onSelectPaletteType,
                    onInfo: _showComponentInfo,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: NeonButton.primary(
                      label: _readyToLaunch ? 'LAUNCH SCHEME' : 'PLACE ALL REQUIRED ROUTERS',
                      icon: _readyToLaunch ? Icons.bolt : Icons.warning_amber_rounded,
                      accent: _readyToLaunch ? AppColors.success : null,
                      size: NeonButtonSize.medium,
                      onPressed: _readyToLaunch ? launch : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final List<BallColor> allowed;
  final BallColor selected;
  final void Function(BallColor) onPicked;
  const _ColorPicker({required this.allowed, required this.selected, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Convert to color', style: titleGlow(size: 16)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          children: [
            for (final c in allowed)
              GestureDetector(
                onTap: () => onPicked(c),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.color,
                    border: Border.all(color: selected == c ? Colors.white : Colors.transparent, width: 3),
                    boxShadow: [BoxShadow(color: c.color.withValues(alpha: 0.7), blurRadius: 12)],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DelayStepper extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onDone;
  const _DelayStepper({required this.value, required this.onChanged, required this.onDone});

  @override
  State<_DelayStepper> createState() => _DelayStepperState();
}

class _DelayStepperState extends State<_DelayStepper> {
  late int _value = widget.value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Delay duration', style: titleGlow(size: 16)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _value > 1
                  ? () => setState(() {
                        _value--;
                        widget.onChanged(_value);
                      })
                  : null,
              icon: const Icon(Icons.remove_circle, color: AppColors.accentCyan),
            ),
            Text('$_value ticks', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            IconButton(
              onPressed: _value < 8
                  ? () => setState(() {
                        _value++;
                        widget.onChanged(_value);
                      })
                  : null,
              icon: const Icon(Icons.add_circle, color: AppColors.accentCyan),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NeonButton.primary(label: 'Done', icon: Icons.check_rounded, size: NeonButtonSize.medium, onPressed: widget.onDone),
      ],
    );
  }
}
