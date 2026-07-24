import 'dart:math';

import '../models/ball_color.dart';
import '../models/component_type.dart';
import '../models/grid_models.dart';
import '../models/level.dart';
import '../models/placed_component.dart';

/// Base number of simulation ticks needed to cross one grid cell at
/// normal speed. Accelerators reduce this; nothing increases it (Delay
/// instead adds a flat pause at the node).
const int kBaseTicksPerHop = 3;
const double kBasePower = 10.0;
const int kResonatorSyncWindow = 5;
const int kGeneratorInterval = 9;
const int kGeneratorMaxSpawns = 4;
const int kAcceleratorBoostHops = 5;

enum SimEventType {
  spawn,
  activate,
  delivered,
  lost,
  resonance,
  generatorAwake,
  generatorSpawn,
}

class SimEvent {
  final SimEventType type;
  final GridPos pos;
  final ComponentType? component;
  final BallColor? color;
  const SimEvent({required this.type, required this.pos, this.component, this.color});
}

class SimBall {
  final int id;
  BallColor color;
  double power;
  GridPos fromNode;
  GridPos toNode;
  Direction travelDir;
  int hopProgress = 0;
  int ticksPerHop;
  int accelHopsRemaining = 0;
  int delayRemaining = 0;
  bool alive = true;

  SimBall({
    required this.id,
    required this.color,
    required this.power,
    required this.fromNode,
    required this.toNode,
    required this.travelDir,
    required this.ticksPerHop,
  });

  /// Interpolation fraction 0..1 between fromNode and toNode for rendering.
  double get renderT => ticksPerHop == 0 ? 1 : hopProgress / ticksPerHop;
}

class SimResult {
  final bool won;
  final int score;
  final int delivered;
  final int lost;
  final int cascadeCount;
  final int stars;
  final Map<BallColor, int> deliveredByColor;
  const SimResult({
    required this.won,
    required this.score,
    required this.delivered,
    required this.lost,
    required this.cascadeCount,
    required this.stars,
    required this.deliveredByColor,
  });
}

/// A pure, deterministic, tick-stepped simulator for a single level run.
/// The UI layer drives [step] on a timer and reads [balls] each frame for
/// rendering, plus consumes [drainEvents] for sound/VFX triggers.
class SimulationEngine {
  final LevelDefinition level;
  final Map<String, PlacedComponent> placements;

  int tick = 0;
  int score = 0;
  int cascadeCount = 0;
  int delivered = 0;
  int lost = 0;
  final Map<BallColor, int> deliveredByColor = {};
  bool finished = false;

  final List<SimBall> balls = [];
  final List<SimEvent> _pendingEvents = [];
  int _nextBallId = 0;

  final Map<String, List<int>> _resonatorHistory = {};
  final Map<String, bool> _generatorActivated = {};
  final Map<String, int> _generatorSpawnCount = {};
  final Map<String, int> _generatorActivatedAtTick = {};

  // Which teleport pairs each individual sphere has already ridden once.
  // A pair can land on the same lane it started from (or on each
  // other's lane); without this guard such a layout would let a sphere
  // ping-pong between the two ends forever. One free ride per sphere
  // per pair keeps Teleport a guaranteed-safe shortcut either way.
  final Map<int, Set<String>> _teleportRidden = {};

  // Mutable per-start spawn cursors.
  final List<List<_SpawnCursor>> _spawnCursors = [];

  // [seed] is accepted for API stability/future use (e.g. deterministic
  // cosmetic variance) - the simulation itself is fully deterministic
  // given a level + placement, with no randomized gameplay outcomes.
  SimulationEngine({required this.level, required this.placements, int? seed}) {
    for (final start in level.starts) {
      _spawnCursors.add([
        for (final spawn in start.spawns) _SpawnCursor(spawn: spawn),
      ]);
    }
  }

  List<SimEvent> drainEvents() {
    final events = List<SimEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    return events;
  }

  BoardNode? _node(GridPos p) => level.nodes[p.key];

  bool get isComplete => finished;

  /// Advances the simulation by one tick. Returns false once no more
  /// spawns are pending and no balls remain alive (simulation over) or
  /// the max tick budget is exhausted.
  bool step() {
    if (finished) return false;
    tick++;

    _processSpawns();
    _processGenerators();

    final snapshot = List<SimBall>.from(balls);
    for (final ball in snapshot) {
      if (!ball.alive) continue;
      _advanceBall(ball);
    }
    balls.removeWhere((b) => !b.alive);

    final noMoreSpawns = _spawnCursors.every((list) => list.every((c) => c.done));
    if ((noMoreSpawns && balls.isEmpty) || tick >= level.maxTicks) {
      finished = true;
      _finish();
    }
    return !finished;
  }

  void _processSpawns() {
    for (var i = 0; i < level.starts.length; i++) {
      final start = level.starts[i];
      final node = _node(start.pos);
      if (node == null || node.connections.isEmpty) continue;
      final outDir = node.connections.first;
      for (final cursor in _spawnCursors[i]) {
        if (cursor.done) continue;
        if (tick < cursor.spawn.startDelayTicks) continue;
        final sinceStart = tick - cursor.spawn.startDelayTicks;
        if (sinceStart % cursor.spawn.intervalTicks == 0) {
          _spawnBall(start.pos, outDir, cursor.spawn.color);
          cursor.spawned++;
          if (cursor.spawned >= cursor.spawn.count) cursor.done = true;
        }
      }
    }
  }

  void _spawnBall(GridPos at, Direction dir, BallColor color) {
    final target = dir.apply(at);
    final ball = SimBall(
      id: _nextBallId++,
      color: color,
      power: kBasePower * color.powerMultiplier,
      fromNode: at,
      toNode: target,
      travelDir: dir,
      ticksPerHop: kBaseTicksPerHop,
    );
    balls.add(ball);
    _pendingEvents.add(SimEvent(type: SimEventType.spawn, pos: at, color: color));
  }

  void _advanceBall(SimBall ball) {
    if (ball.delayRemaining > 0) {
      ball.delayRemaining--;
      return;
    }
    ball.hopProgress++;
    if (ball.hopProgress < ball.ticksPerHop) return;

    // Arrived at ball.toNode.
    final arrivedAt = ball.toNode;
    final node = _node(arrivedAt);
    if (node == null) {
      _loseBall(ball, arrivedAt);
      return;
    }

    if (node.kind == NodeKind.receiver) {
      _deliverBall(ball, arrivedAt);
      return;
    }

    final placed = placements[arrivedAt.key];

    if (node.kind == NodeKind.mandatoryRouter) {
      if (placed == null) {
        _loseBall(ball, arrivedAt);
        return;
      }
      if (placed.type == ComponentType.divider) {
        _handleDivider(ball, arrivedAt, node);
      } else {
        _handleIntersection(ball, arrivedAt, node);
      }
      return;
    } else if (placed != null) {
      _applyLinearComponent(ball, arrivedAt, node, placed);
      // Teleport already repositions the ball and picks its own exit
      // direction from the *destination* node - falling through to
      // _routeStraightOrTurn below would immediately overwrite that
      // with a bogus route computed against the *origin* node instead.
      if (placed.type == ComponentType.teleport) return;
    }

    if (!ball.alive) return;
    _routeStraightOrTurn(ball, arrivedAt, node);
  }

  void _routeStraightOrTurn(SimBall ball, GridPos at, BoardNode node) {
    final reverseOfTravel = ball.travelDir.opposite;
    Direction? outDir;
    for (final d in node.connections) {
      if (d != reverseOfTravel) {
        outDir = d;
        break;
      }
    }
    if (outDir == null) {
      _loseBall(ball, at);
      return;
    }
    ball.fromNode = at;
    ball.toNode = outDir.apply(at);
    ball.travelDir = outDir;
    ball.hopProgress = 0;
  }

  void _handleDivider(SimBall ball, GridPos at, BoardNode node) {
    final reverseOfTravel = ball.travelDir.opposite;
    final outputs = node.connections.where((d) => d != reverseOfTravel).toList();
    if (outputs.isEmpty) {
      _loseBall(ball, at);
      return;
    }
    final childPower = max(4.0, ball.power / outputs.length);
    for (final dir in outputs) {
      final child = SimBall(
        id: _nextBallId++,
        color: ball.color,
        power: childPower,
        fromNode: at,
        toNode: dir.apply(at),
        travelDir: dir,
        ticksPerHop: ball.ticksPerHop,
      );
      balls.add(child);
    }
    ball.alive = false;
    _activate(at, ComponentType.divider, cascadeAdd: outputs.length, scoreBonus: 0);
  }

  void _handleIntersection(SimBall ball, GridPos at, BoardNode node) {
    // Straight pass-through: keep the same travel direction.
    if (!node.connections.contains(ball.travelDir)) {
      _loseBall(ball, at);
      return;
    }
    ball.fromNode = at;
    ball.toNode = ball.travelDir.apply(at);
    ball.hopProgress = 0;
    _activate(at, ComponentType.intersection, cascadeAdd: 1, scoreBonus: 0);
  }

  void _applyLinearComponent(SimBall ball, GridPos at, BoardNode node, PlacedComponent placed) {
    switch (placed.type) {
      case ComponentType.amplifier:
        ball.power += 4;
        _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 0);
        break;
      case ComponentType.delay:
        ball.delayRemaining = placed.delayTicks.clamp(1, 8);
        _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 0);
        break;
      case ComponentType.colorConverter:
        ball.color = placed.targetColor ?? ball.color;
        _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 0);
        break;
      case ComponentType.accelerator:
        ball.accelHopsRemaining = kAcceleratorBoostHops;
        ball.ticksPerHop = max(1, kBaseTicksPerHop - 2);
        _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 0);
        break;
      case ComponentType.magnet:
        final nearby = balls.where((b) => b.alive && b.id != ball.id && _chebyshev(b.toNode, at) <= 2).length;
        if (nearby >= 1) {
          ball.power += 3;
          _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 4);
        }
        break;
      case ComponentType.resonator:
        final history = _resonatorHistory.putIfAbsent(at.key, () => []);
        final rare = ball.color.isRareEnergizer;
        // Purple/White spheres resonate with the rare tech more readily -
        // a wider sync window and a bigger payoff when it lands.
        final window = rare ? kResonatorSyncWindow + 2 : kResonatorSyncWindow;
        final synced = history.any((t) => (tick - t).abs() <= window);
        history.add(tick);
        if (synced) {
          ball.power *= rare ? 2.2 : 1.6;
          _activate(at, placed.type, cascadeAdd: 3, scoreBonus: rare ? 26 : 18);
        } else if (rare) {
          // Even without perfect sync, a rare energizer still primes the
          // resonator a little - never a wasted placement for Purple/White.
          ball.power += 5;
          _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 6);
        }
        break;
      case ComponentType.teleport:
        _handleTeleport(ball, at, placed);
        break;
      case ComponentType.generator:
        ball.power += 1;
        if (ball.color.canTriggerGenerator || ball.color.isHighPower) {
          if (_generatorActivated[at.key] != true) {
            _generatorActivated[at.key] = true;
            _generatorActivatedAtTick[at.key] = tick;
            _pendingEvents.add(SimEvent(type: SimEventType.generatorAwake, pos: at, component: placed.type));
          }
        }
        _activate(at, placed.type, cascadeAdd: 1, scoreBonus: 0);
        break;
      case ComponentType.divider:
      case ComponentType.intersection:
        break; // handled elsewhere
    }

    // Decay accelerator boost once the ball leaves an accelerated stretch
    // (checked every hop so the effect lasts a bounded number of hops).
    if (placed.type != ComponentType.accelerator && ball.accelHopsRemaining > 0) {
      ball.accelHopsRemaining--;
      if (ball.accelHopsRemaining == 0) ball.ticksPerHop = kBaseTicksPerHop;
    }
  }

  void _handleTeleport(SimBall ball, GridPos at, PlacedComponent placed) {
    String? otherKey;
    for (final entry in placements.entries) {
      if (entry.value.type == ComponentType.teleport && entry.key != at.key) {
        otherKey = entry.key;
        break;
      }
    }
    if (otherKey == null) return; // acts as plain wire without a pair
    final ridden = _teleportRidden.putIfAbsent(ball.id, () => {});
    if (ridden.contains(at.key)) return; // already used this pair once - plain wire from here on
    final destNode = level.nodes[otherKey];
    if (destNode == null || destNode.connections.isEmpty) return;
    ridden.add(at.key);
    ridden.add(otherKey);
    // Always exit toward the destination node's own Receiver (its
    // precomputed "forward" direction from generation time), never back
    // toward its Start. This is what makes Teleport safe to use even
    // when the paired node sits earlier on a completely different lane -
    // no dice rolls, no risk of silently stranding the sphere.
    final outDir = (destNode.forwardDir != null && destNode.connections.contains(destNode.forwardDir))
        ? destNode.forwardDir!
        : (destNode.connections.contains(ball.travelDir) ? ball.travelDir : destNode.connections.first);
    ball.fromNode = destNode.pos;
    ball.toNode = outDir.apply(destNode.pos);
    ball.travelDir = outDir;
    ball.hopProgress = 0;
    _activate(at, placed.type, cascadeAdd: 1, scoreBonus: ball.color.isRareEnergizer ? 10 : 6);
  }

  void _processGenerators() {
    for (final entry in _generatorActivated.entries) {
      if (!entry.value) continue;
      final key = entry.key;
      final placed = placements[key];
      if (placed == null || placed.type != ComponentType.generator) continue;
      final spawned = _generatorSpawnCount[key] ?? 0;
      if (spawned >= kGeneratorMaxSpawns) continue;
      final startedAt = _generatorActivatedAtTick[key] ?? tick;
      if ((tick - startedAt) % kGeneratorInterval != 0) continue;
      final node = level.nodes[key];
      if (node == null || node.connections.isEmpty) continue;
      final dir = node.connections.first;
      _spawnBall(node.pos, dir, BallColor.white);
      _generatorSpawnCount[key] = spawned + 1;
      _pendingEvents.add(SimEvent(type: SimEventType.generatorSpawn, pos: node.pos, component: ComponentType.generator));
    }
  }

  void _deliverBall(SimBall ball, GridPos at) {
    ball.alive = false;
    delivered++;
    deliveredByColor[ball.color] = (deliveredByColor[ball.color] ?? 0) + 1;
    final points = (ball.power * ball.color.scoreMultiplier).round();
    score += points;
    _pendingEvents.add(SimEvent(type: SimEventType.delivered, pos: at, color: ball.color));
  }

  void _loseBall(SimBall ball, GridPos at) {
    ball.alive = false;
    lost++;
    _pendingEvents.add(SimEvent(type: SimEventType.lost, pos: at, color: ball.color));
  }

  void _activate(GridPos at, ComponentType type, {int cascadeAdd = 1, int scoreBonus = 0}) {
    cascadeCount += cascadeAdd;
    score += cascadeAdd * 2 + scoreBonus;
    _pendingEvents.add(SimEvent(type: SimEventType.activate, pos: at, component: type));
    if (scoreBonus >= 10) {
      _pendingEvents.add(SimEvent(type: SimEventType.resonance, pos: at, component: type));
    }
  }

  int _chebyshev(GridPos a, GridPos b) => max((a.row - b.row).abs(), (a.col - b.col).abs());

  void _finish() {
    final goal = level.goal;
    final metScore = score >= goal.minScore;
    final metDelivered = delivered >= goal.minDelivered;
    final metCascade = cascadeCount >= goal.minCascade;
    final won = metScore && metDelivered && metCascade;
    int stars = 0;
    if (won) {
      stars = 1;
      if (score >= goal.star2Score) stars = 2;
      if (score >= goal.star3Score) stars = 3;
    }
    _lastResult = SimResult(
      won: won,
      score: score,
      delivered: delivered,
      lost: lost,
      cascadeCount: cascadeCount,
      stars: stars,
      deliveredByColor: deliveredByColor,
    );
  }

  SimResult? _lastResult;
  SimResult? get result => _lastResult;

  /// Runs the whole simulation synchronously (no rendering), used for
  /// level-generation sanity checks and for instant "skip" playback.
  SimResult runToCompletion({int maxSteps = 5000}) {
    var guard = 0;
    while (!finished && guard < maxSteps) {
      step();
      guard++;
    }
    return _lastResult ??
        SimResult(won: false, score: score, delivered: delivered, lost: lost, cascadeCount: cascadeCount, stars: 0, deliveredByColor: deliveredByColor);
  }
}

class _SpawnCursor {
  final BallSpawn spawn;
  int spawned = 0;
  bool done = false;
  _SpawnCursor({required this.spawn});
}
