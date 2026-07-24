import 'dart:math';

import '../models/ball_color.dart';
import '../models/component_type.dart';
import '../models/grid_models.dart';
import '../models/level.dart';
import '../models/placed_component.dart';
import 'path_carver.dart';
import 'simulation_engine.dart' show SimulationEngine, kBaseTicksPerHop;

/// Chapter-level tuning knobs. Chapters introduce mechanics gradually as
/// described in the design document: chapter 0 is a pure-linear tutorial,
/// each following chapter layers on one or two new component types plus
/// a new sphere color, and later chapters combine everything on bigger
/// boards with more lanes.
class _ChapterSpec {
  final String name;
  final int lanes;
  final int branchesPerLane;
  final bool allowCrossings;
  final Set<BallColor> colors;
  final int baseRows;
  final int baseCols;

  const _ChapterSpec({
    required this.name,
    required this.lanes,
    required this.branchesPerLane,
    required this.allowCrossings,
    required this.colors,
    required this.baseRows,
    required this.baseCols,
  });
}

final List<_ChapterSpec> _chapters = [
  _ChapterSpec(
    name: 'Spark Basics',
    lanes: 1,
    branchesPerLane: 0,
    allowCrossings: false,
    colors: {BallColor.white, BallColor.blue},
    baseRows: 7,
    baseCols: 5,
  ),
  _ChapterSpec(
    name: 'Divider Lab',
    lanes: 1,
    branchesPerLane: 1,
    allowCrossings: false,
    colors: {BallColor.white, BallColor.blue, BallColor.red},
    baseRows: 8,
    baseCols: 5,
  ),
  _ChapterSpec(
    name: 'Speed & Color',
    lanes: 1,
    branchesPerLane: 2,
    allowCrossings: false,
    colors: {BallColor.white, BallColor.blue, BallColor.red, BallColor.green},
    baseRows: 9,
    baseCols: 6,
  ),
  _ChapterSpec(
    name: 'Crossroads',
    lanes: 2,
    branchesPerLane: 1,
    allowCrossings: true,
    colors: {BallColor.white, BallColor.blue, BallColor.red, BallColor.green, BallColor.yellow},
    baseRows: 9,
    baseCols: 7,
  ),
  _ChapterSpec(
    name: 'Magnetic Fields',
    lanes: 2,
    branchesPerLane: 2,
    allowCrossings: true,
    colors: {
      BallColor.white,
      BallColor.blue,
      BallColor.red,
      BallColor.green,
      BallColor.yellow,
      BallColor.purple,
    },
    baseRows: 10,
    baseCols: 7,
  ),
  _ChapterSpec(
    name: 'Resonance Deck',
    lanes: 2,
    branchesPerLane: 2,
    allowCrossings: true,
    colors: BallColor.values.toSet(),
    baseRows: 10,
    baseCols: 8,
  ),
  _ChapterSpec(
    name: 'Generator Core',
    lanes: 3,
    branchesPerLane: 1,
    allowCrossings: true,
    colors: BallColor.values.toSet(),
    baseRows: 11,
    baseCols: 8,
  ),
  _ChapterSpec(
    name: 'Master Grid',
    lanes: 3,
    branchesPerLane: 2,
    allowCrossings: true,
    colors: BallColor.values.toSet(),
    baseRows: 12,
    baseCols: 9,
  ),
];

/// Returns [count] distinct column indices spread evenly across
/// [0, cols - 1], with a touch of random jitter for variety.
List<int> _spreadColumns(int count, int cols, Random rng) {
  final result = <int>[];
  final used = <int>{};
  for (var i = 0; i < count; i++) {
    var col = ((i + 1) * cols / (count + 1)).round().clamp(0, cols - 1);
    var jitterAttempts = 0;
    while (used.contains(col) && jitterAttempts < cols) {
      col = (col + 1) % cols;
      jitterAttempts++;
    }
    used.add(col);
    result.add(col);
  }
  return result;
}

class _MutableNode {
  final GridPos pos;
  NodeKind kind;
  final Set<Direction> connections = {};
  bool isCrossing = false;
  int? specIndex;
  Direction? forwardDir;

  _MutableNode(this.pos, this.kind);
}

class LevelGenerator {
  static const int totalLevels = 40;
  static const int levelsPerChapter = 5;

  static int chapterOf(int levelId) => (levelId - 1) ~/ levelsPerChapter;
  static int indexInChapterOf(int levelId) => (levelId - 1) % levelsPerChapter;
  static int get chapterCount => _chapters.length;
  static String chapterName(int chapter) => _chapters[chapter.clamp(0, _chapters.length - 1)].name;

  /// Generates a level for Endless mode. Unlike the campaign, this is not
  /// bounded to 40 ids - [round] climbs forever, steadily unlocking every
  /// chapter's mechanics and then continuing to scale board size and
  /// goals so every run is a fresh, tougher engineering challenge.
  static LevelDefinition generateEndlessRound(int round) {
    final chapter = (round ~/ 3).clamp(0, _chapters.length - 1);
    final spec = _chapters[chapter];
    final scale = 1.0 + (round - 1) * 0.09;
    for (var attempt = 0; attempt < 6; attempt++) {
      final seed = round * 514229 + attempt * 7919 + 3;
      final result = _tryGenerate(90000 + round, chapter, round % levelsPerChapter, spec, Random(seed));
      if (result == null) continue;
      final g = result.goal;
      final scaledGoal = LevelGoal(
        minScore: (g.minScore * scale).round(),
        star2Score: (g.star2Score * scale).round(),
        star3Score: (g.star3Score * scale).round(),
        minDelivered: g.minDelivered,
        minCascade: g.minCascade,
      );
      return LevelDefinition(
        id: result.id,
        chapter: result.chapter,
        indexInChapter: result.indexInChapter,
        name: 'Round $round',
        rows: result.rows,
        cols: result.cols,
        nodes: result.nodes,
        starts: result.starts,
        receivers: result.receivers,
        inventory: result.inventory,
        mandatorySlots: result.mandatorySlots,
        allowedColors: result.allowedColors,
        goal: scaledGoal,
        backgroundIndex: ((round - 1) % 11) + 1,
        maxTicks: result.maxTicks,
      );
    }
    return _fallbackLinearLevel(90000 + round, chapter, round % levelsPerChapter, spec);
  }

  static LevelDefinition generate(int levelId) {
    assert(levelId >= 1 && levelId <= totalLevels);
    final chapter = chapterOf(levelId);
    final indexInChapter = indexInChapterOf(levelId);
    final spec = _chapters[chapter.clamp(0, _chapters.length - 1)];

    for (var attempt = 0; attempt < 6; attempt++) {
      final seed = levelId * 92821 + attempt * 104729 + 17;
      final result = _tryGenerate(levelId, chapter, indexInChapter, spec, Random(seed));
      if (result != null) return result;
    }
    // Guaranteed-safe fallback: a simple straight-ish single lane.
    return _fallbackLinearLevel(levelId, chapter, indexInChapter, spec);
  }

  static LevelDefinition? _tryGenerate(
    int levelId,
    int chapter,
    int indexInChapter,
    _ChapterSpec spec,
    Random rng,
  ) {
    final rows = (spec.baseRows + (indexInChapter >= 3 ? 1 : 0)).clamp(5, 13);
    final cols = (spec.baseCols + (indexInChapter >= 4 ? 1 : 0)).clamp(4, 9);

    final nodes = <String, _MutableNode>{};
    final used = <GridPos>{};
    final crossings = <GridPos>{};

    _MutableNode nodeAt(GridPos p) => nodes.putIfAbsent(p.key, () => _MutableNode(p, NodeKind.wire));

    void addEdge(GridPos a, GridPos b) {
      final da = directionBetween(a, b);
      nodeAt(a).connections.add(da);
      nodeAt(b).connections.add(da.opposite);
    }

    // `used` only ever holds cells committed by lanes/branches that have
    // *already finished* generating - never the path currently being
    // searched (PathCarver already prevents self-intersection internally
    // via its own visited set), so there is no risk of a path falsely
    // reading itself as an obstacle.
    bool axisVertical(Direction d) => d == Direction.up || d == Direction.down;

    final starts = <StartSpec>[];
    final receivers = <ReceiverSpec>[];
    final lanePaths = <List<GridPos>>[];

    final laneCount = spec.lanes;
    final startCols = _spreadColumns(laneCount, cols, rng);
    final endCols = _spreadColumns(laneCount, cols, rng)..shuffle(rng);
    for (var lane = 0; lane < laneCount; lane++) {
      final startPos = GridPos(0, startCols[lane]);
      final endPos = GridPos(rows - 1, endCols[lane]);
      if (used.contains(startPos) || used.contains(endPos)) return null;

      bool isBlocked(GridPos p) {
        if (!used.contains(p)) return false;
        // Allow a clean perpendicular crossing through a cell already
        // used by an earlier lane, if crossings are permitted for this
        // chapter and the cell isn't already a crossing.
        if (!spec.allowCrossings) return true;
        if (crossings.contains(p)) return true;
        final existing = nodes[p.key];
        if (existing == null || existing.connections.length != 2) return true;
        final dirs = existing.connections;
        final isStraight = (dirs.contains(Direction.up) && dirs.contains(Direction.down)) ||
            (dirs.contains(Direction.left) && dirs.contains(Direction.right));
        return !isStraight;
      }

      final carver = PathCarver(
        rng: rng,
        rows: rows,
        cols: cols,
        isBlocked: isBlocked,
        windiness: 0.3 + chapter * 0.03,
      );
      final path = carver.findPath(startPos, endPos, maxLen: rows * cols);
      if (path == null || path.length < 3) return null;

      // Validate crossing cleanliness for any interior node that belongs
      // to an already-committed lane: the new lane must pass straight
      // through on the perpendicular axis (a true "+" crossing), never a
      // turn, and never re-use the same axis as the existing lane.
      for (var i = 1; i < path.length - 1; i++) {
        final node = path[i];
        if (!used.contains(node)) continue;
        final existingDirs = nodes[node.key]!.connections;
        final existingIsVertical = existingDirs.contains(Direction.up);
        final dirIn = directionBetween(path[i - 1], node);
        final dirOut = directionBetween(node, path[i + 1]);
        final newLaneStraight = dirOut == dirIn;
        final newLaneVertical = axisVertical(dirIn);
        if (!newLaneStraight || newLaneVertical == existingIsVertical) {
          return null;
        }
      }

      for (var i = 0; i < path.length - 1; i++) {
        final a = path[i];
        final b = path[i + 1];
        if (used.contains(a) && a != startPos) crossings.add(a);
        addEdge(a, b);
        // "Forward" at `a` is the direction it takes toward `b`, i.e.
        // away from this lane's Start and toward its Receiver.
        nodeAt(a).forwardDir ??= directionBetween(a, b);
      }
      used.addAll(path);

      starts.add(StartSpec(pos: startPos, spawns: _buildSpawns(chapter, indexInChapter, spec, rng)));
      receivers.add(ReceiverSpec(pos: endPos));
      lanePaths.add(path);
      nodeAt(startPos).kind = NodeKind.start;
      nodeAt(startPos).specIndex = lane;
      nodeAt(endPos).kind = NodeKind.receiver;
      nodeAt(endPos).specIndex = lane;
    }

    // Grow side-branches (Dividers) off interior main-lane cells.
    var branchReceiverCount = 0;
    for (var lane = 0; lane < laneCount; lane++) {
      final path = lanePaths[lane];
      final branchCount = spec.branchesPerLane;
      final interior = path.sublist(1, path.length - 1);
      if (interior.isEmpty) continue;
      interior.shuffle(rng);
      var grown = 0;
      for (final root in interior) {
        if (grown >= branchCount) break;
        // Pick a branch target roughly toward the bottom of the board,
        // away from the root, to keep branches from tangling immediately.
        final targetRow = (root.row + 2 + rng.nextInt(3)).clamp(0, rows - 1);
        final targetCol = rng.nextInt(cols);
        final target = GridPos(targetRow, targetCol);
        if (used.contains(target) || target == root) continue;

        bool isBlocked(GridPos p) => used.contains(p) && p != root;
        final carver = PathCarver(
          rng: rng,
          rows: rows,
          cols: cols,
          isBlocked: isBlocked,
          windiness: 0.4,
          maxExpansions: 3000,
        );
        final branchPath = carver.findPath(root, target, maxLen: (rows * cols / 2).round());
        if (branchPath == null || branchPath.length < 3) continue;

        for (var i = 0; i < branchPath.length - 1; i++) {
          addEdge(branchPath[i], branchPath[i + 1]);
          nodeAt(branchPath[i]).forwardDir ??= directionBetween(branchPath[i], branchPath[i + 1]);
        }
        used.addAll(branchPath);
        final branchReceiver = branchPath.last;
        nodeAt(branchReceiver).kind = NodeKind.receiver;
        nodeAt(branchReceiver).specIndex = laneCount + branchReceiverCount;
        receivers.add(ReceiverSpec(pos: branchReceiver));
        branchReceiverCount++;
        grown++;
      }
    }

    // Classify remaining nodes by degree; mark crossings explicitly.
    final mandatorySlots = <String, ComponentType>{};
    for (final n in nodes.values) {
      if (n.kind == NodeKind.start || n.kind == NodeKind.receiver) continue;
      if (crossings.contains(n.pos) && n.connections.length == 4) {
        n.kind = NodeKind.mandatoryRouter;
        n.isCrossing = true;
        mandatorySlots[n.pos.key] = ComponentType.intersection;
      } else if (n.connections.length >= 3) {
        n.kind = NodeKind.mandatoryRouter;
        n.isCrossing = false;
        mandatorySlots[n.pos.key] = ComponentType.divider;
      } else {
        n.kind = NodeKind.wire;
      }
    }

    // Sanity: need at least one interior wire node to place anything on
    // for chapter 0+ variety, and the graph should have a reasonable size.
    if (nodes.length < 4) return null;

    // Turn a fraction of plain wire nodes into optional component slots.
    final optionalFraction = (0.45 + chapter * 0.04).clamp(0.3, 0.75);
    final wireNodes = nodes.values.where((n) => n.kind == NodeKind.wire).toList();
    wireNodes.shuffle(rng);
    final optionalCount = (wireNodes.length * optionalFraction).round();
    for (var i = 0; i < optionalCount && i < wireNodes.length; i++) {
      wireNodes[i].kind = NodeKind.optionalSlot;
    }

    final linearTypes = ComponentType.values.where((t) => !t.isRouter && t.unlockChapter <= chapter).toList();
    final totalOptionalSlots = wireNodes.take(optionalCount).length;
    final inventory = <ComponentType, int>{};
    for (final n in mandatorySlots.values) {
      inventory[n] = (inventory[n] ?? 0) + 1;
    }
    if (linearTypes.isNotEmpty && totalOptionalSlots > 0) {
      final budget = (totalOptionalSlots * 0.7).ceil().clamp(1, totalOptionalSlots);
      var remaining = budget;
      var typeIdx = 0;
      while (remaining > 0) {
        final t = linearTypes[typeIdx % linearTypes.length];
        inventory[t] = (inventory[t] ?? 0) + 1;
        remaining--;
        typeIdx++;
      }
    }

    final totalBalls = starts.fold<int>(0, (s, st) => s + st.totalBalls);
    if (totalBalls == 0) return null;

    final builtNodes = nodes.map((k, v) => MapEntry(k, _toBoardNode(v)));
    final builtMandatory = mandatorySlots.map((k, v) => MapEntry(k, v));

    final draft = LevelDefinition(
      id: levelId,
      chapter: chapter,
      indexInChapter: indexInChapter,
      name: '${spec.name} ${indexInChapter + 1}',
      rows: rows,
      cols: cols,
      nodes: builtNodes,
      starts: starts,
      receivers: receivers,
      inventory: inventory,
      mandatorySlots: builtMandatory,
      allowedColors: spec.colors,
      goal: const LevelGoal(minScore: 0, star2Score: 0, star3Score: 0),
      backgroundIndex: chapter + 1,
      maxTicks: _safeMaxTicks(rows, cols, totalBalls),
    );

    final goal = _calibrateGoal(
      draft: draft,
      mandatorySlots: builtMandatory,
      inventory: inventory,
      chapter: chapter,
    );

    return draft.copyWith(goal: goal);
  }

  /// Runs two "probe" simulations against a level whose graph/inventory
  /// are already final but whose goal is still a placeholder:
  ///  - baseline: only the *mandatory* routers are placed (the absolute
  ///    minimum needed to even launch the scheme) - representing a
  ///    player who ignores the strategic layer entirely.
  ///  - smart: every optional slot is additionally filled using a
  ///    reasonable greedy priority order over the available inventory -
  ///    representing a player who actually engineers the circuit.
  ///
  /// The win/star thresholds are then derived from the *gap* between
  /// these two outcomes, so a bare-minimum scheme reliably falls short
  /// of the goal while a thoughtfully-built one reliably clears it -
  /// with 3-star mastery reserved for going beyond the simple greedy
  /// heuristic (e.g. hand-tuned delays/resonance syncing).
  static LevelGoal _calibrateGoal({
    required LevelDefinition draft,
    required Map<String, ComponentType> mandatorySlots,
    required Map<ComponentType, int> inventory,
    required int chapter,
  }) {
    // Probe with the exact same seed the real SimulationEngine defaults
    // to for this level (see SimulationEngine's constructor) so goals
    // are calibrated against precisely what the player will experience
    // (teleport exit choices etc. are seeded, not truly random, but
    // must match to keep the calibration meaningful).
    final canonicalSeed = draft.id * 733 + 11;
    final baselinePlacements = <String, PlacedComponent>{
      for (final e in mandatorySlots.entries) e.key: PlacedComponent(nodeKey: e.key, type: e.value),
    };
    final baseline =
        SimulationEngine(level: draft, placements: baselinePlacements, seed: canonicalSeed).runToCompletion();

    const priority = [
      ComponentType.resonator,
      ComponentType.amplifier,
      ComponentType.magnet,
      ComponentType.accelerator,
      ComponentType.generator,
      ComponentType.colorConverter,
      ComponentType.teleport,
      ComponentType.delay,
    ];
    final priorityOrder = priority.where((t) => t.unlockChapter <= chapter).toList();
    final invCopy = Map<ComponentType, int>.from(inventory);
    for (final t in mandatorySlots.values) {
      invCopy[t] = (invCopy[t] ?? 1) - 1;
    }
    final smartPlacements = Map<String, PlacedComponent>.from(baselinePlacements);
    for (final key in draft.optionalSlotKeys) {
      for (final t in priorityOrder) {
        if ((invCopy[t] ?? 0) > 0) {
          smartPlacements[key] = PlacedComponent(
            nodeKey: key,
            type: t,
            targetColor: t.needsColorConfig ? draft.allowedColors.first : null,
            delayTicks: 3,
          );
          invCopy[t] = invCopy[t]! - 1;
          break;
        }
      }
    }
    final smart = SimulationEngine(level: draft, placements: smartPlacements, seed: canonicalSeed).runToCompletion();

    final baseScore = baseline.score;
    final ceilScore = max(smart.score, baseScore);
    final gap = ceilScore - baseScore;

    int minScore;
    int star2Score;
    int star3Score;
    if (gap >= 8) {
      minScore = (baseScore + gap * 0.5).round().clamp(baseScore + 4, ceilScore - 2);
      star2Score = (baseScore + gap * 0.85).round().clamp(minScore + 3, ceilScore + gap);
      star3Score = (ceilScore + gap * 0.18).round() + 5;
    } else {
      // Almost no strategic gap available on this particular board shape
      // (e.g. very few optional slots) - keep the level guaranteed
      // winnable rather than risk an impossible goal.
      minScore = baseScore + 1;
      star2Score = ceilScore + 3;
      star3Score = ceilScore + (ceilScore * 0.12).round() + 6;
    }
    if (star2Score <= minScore) star2Score = minScore + 3;
    if (star3Score <= star2Score) star3Score = star2Score + 5;

    final minDelivered = max(1, (baseline.delivered * 0.6).ceil());
    final desiredCascade = chapter >= 4 ? (draft.totalOptionalSlots * 0.3).round() : 0;
    final minCascade = min(desiredCascade, baseline.cascadeCount);

    return LevelGoal(
      minScore: minScore,
      star2Score: star2Score,
      star3Score: star3Score,
      minDelivered: minDelivered,
      minCascade: minCascade,
    );
  }

  /// Generous tick budget so every spawned sphere - including split
  /// children born late from far-away Dividers - has time to traverse
  /// the whole board before the run is cut off.
  static int _safeMaxTicks(int rows, int cols, int totalBalls) {
    return 150 + rows * cols * kBaseTicksPerHop * 2 + totalBalls * 9;
  }

  static BoardNode _toBoardNode(_MutableNode n) {
    return BoardNode(
      pos: n.pos,
      kind: n.kind,
      connections: n.connections,
      isCrossing: n.isCrossing,
      specIndex: n.specIndex,
      forwardDir: n.forwardDir,
    );
  }

  static List<BallSpawn> _buildSpawns(int chapter, int indexInChapter, _ChapterSpec spec, Random rng) {
    final colors = spec.colors.toList();
    final baseCount = 3 + chapter + indexInChapter ~/ 2;
    if (colors.length == 1) {
      return [BallSpawn(color: colors.first, count: baseCount, intervalTicks: 6)];
    }
    // Favor the most recently unlocked color plus a staple older one.
    colors.shuffle(rng);
    final primary = colors.first;
    final secondary = colors.length > 1 ? colors[1] : colors.first;
    final primaryCount = (baseCount * 0.6).ceil().clamp(2, 20);
    final secondaryCount = (baseCount - primaryCount).clamp(1, 20);
    return [
      BallSpawn(color: primary, count: primaryCount, intervalTicks: 6, startDelayTicks: 0),
      if (secondaryCount > 0)
        BallSpawn(color: secondary, count: secondaryCount, intervalTicks: 7, startDelayTicks: 3),
    ];
  }

  static LevelDefinition _fallbackLinearLevel(
    int levelId,
    int chapter,
    int indexInChapter,
    _ChapterSpec spec,
  ) {
    final rows = spec.baseRows;
    const cols = 3;
    final nodes = <String, BoardNode>{};
    final path = <GridPos>[for (var r = 0; r < rows; r++) GridPos(r, 1)];
    final mutable = <String, _MutableNode>{};
    for (var i = 0; i < path.length; i++) {
      final n = _MutableNode(path[i], NodeKind.wire);
      if (i == 0) {
        n.kind = NodeKind.start;
        n.specIndex = 0;
      } else if (i == path.length - 1) {
        n.kind = NodeKind.receiver;
        n.specIndex = 0;
      } else if (i.isEven) {
        n.kind = NodeKind.optionalSlot;
      }
      if (i > 0) {
        final dir = directionBetween(path[i - 1], path[i]);
        n.connections.add(dir.opposite);
        mutable[path[i - 1].key]!.connections.add(dir);
        mutable[path[i - 1].key]!.forwardDir = dir;
      }
      mutable[path[i].key] = n;
    }
    for (final e in mutable.entries) {
      nodes[e.key] = _toBoardNode(e.value);
    }
    final ballCount = 3 + chapter;
    const fallbackInventory = {ComponentType.amplifier: 2, ComponentType.delay: 1};
    final draft = LevelDefinition(
      id: levelId,
      chapter: chapter,
      indexInChapter: indexInChapter,
      name: '${spec.name} ${indexInChapter + 1}',
      rows: rows,
      cols: cols,
      nodes: nodes.map((k, v) => MapEntry(k, v)),
      starts: [
        StartSpec(pos: path.first, spawns: [BallSpawn(color: spec.colors.first, count: ballCount)])
      ],
      receivers: [ReceiverSpec(pos: path.last)],
      inventory: fallbackInventory,
      mandatorySlots: const {},
      allowedColors: spec.colors,
      goal: const LevelGoal(minScore: 0, star2Score: 0, star3Score: 0),
      backgroundIndex: chapter + 1,
      maxTicks: _safeMaxTicks(rows, cols, ballCount),
    );
    final goal = _calibrateGoal(
      draft: draft,
      mandatorySlots: const {},
      inventory: fallbackInventory,
      chapter: chapter,
    );
    return draft.copyWith(goal: goal);
  }
}
