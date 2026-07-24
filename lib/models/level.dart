import 'ball_color.dart';
import 'component_type.dart';
import 'grid_models.dart';

/// One scheduled sphere spawn from a start node.
class BallSpawn {
  final BallColor color;
  final int count;
  final int intervalTicks;
  final int startDelayTicks;

  const BallSpawn({
    required this.color,
    required this.count,
    this.intervalTicks = 6,
    this.startDelayTicks = 0,
  });
}

class StartSpec {
  final GridPos pos;
  final List<BallSpawn> spawns;
  const StartSpec({required this.pos, required this.spawns});

  int get totalBalls => spawns.fold(0, (sum, s) => sum + s.count);
}

class ReceiverSpec {
  final GridPos pos;
  const ReceiverSpec({required this.pos});
}

/// Victory conditions & star thresholds for a level.
class LevelGoal {
  final int minScore;
  final int star2Score;
  final int star3Score;
  final int minDelivered;
  final int minCascade;

  const LevelGoal({
    required this.minScore,
    required this.star2Score,
    required this.star3Score,
    this.minDelivered = 0,
    this.minCascade = 0,
  });
}

/// A fully generated, playable level: the graph, the inventory of
/// placeable components, and the victory goal.
class LevelDefinition {
  final int id; // 1-based, 1..40
  final int chapter; // 0-based
  final int indexInChapter; // 0-based
  final String name;
  final int rows;
  final int cols;
  final Map<String, BoardNode> nodes; // key = GridPos.key
  final List<StartSpec> starts;
  final List<ReceiverSpec> receivers;
  final Map<ComponentType, int> inventory;
  final Map<String, ComponentType> mandatorySlots; // nodeKey -> required type
  final Set<BallColor> allowedColors;
  final LevelGoal goal;
  final int backgroundIndex;
  final int maxTicks;

  const LevelDefinition({
    required this.id,
    required this.chapter,
    required this.indexInChapter,
    required this.name,
    required this.rows,
    required this.cols,
    required this.nodes,
    required this.starts,
    required this.receivers,
    required this.inventory,
    required this.mandatorySlots,
    required this.allowedColors,
    required this.goal,
    required this.backgroundIndex,
    required this.maxTicks,
  });

  List<String> get optionalSlotKeys => nodes.entries
      .where((e) => e.value.kind == NodeKind.optionalSlot)
      .map((e) => e.key)
      .toList();

  int get totalOptionalSlots => optionalSlotKeys.length;

  int get totalBallsPlanned => starts.fold(0, (sum, s) => sum + s.totalBalls);

  /// Returns a copy of this level with a different [goal]. Used by the
  /// generator to run "probe" simulations against a placeholder goal
  /// before calibrating the real win/star thresholds.
  LevelDefinition copyWith({LevelGoal? goal}) {
    return LevelDefinition(
      id: id,
      chapter: chapter,
      indexInChapter: indexInChapter,
      name: name,
      rows: rows,
      cols: cols,
      nodes: nodes,
      starts: starts,
      receivers: receivers,
      inventory: inventory,
      mandatorySlots: mandatorySlots,
      allowedColors: allowedColors,
      goal: goal ?? this.goal,
      backgroundIndex: backgroundIndex,
      maxTicks: maxTicks,
    );
  }
}
