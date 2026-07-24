import 'package:flutter_test/flutter_test.dart';
import 'package:radiant_drop_path/engine/level_generator.dart';
import 'package:radiant_drop_path/engine/simulation_engine.dart';
import 'package:radiant_drop_path/models/component_type.dart';
import 'package:radiant_drop_path/models/grid_models.dart';
import 'package:radiant_drop_path/models/placed_component.dart';
import 'package:radiant_drop_path/models/ball_color.dart';

/// BFS over the raw connection graph (ignoring component behaviour) just
/// to confirm every start node can structurally reach at least one
/// receiver node - a basic solvability sanity check independent of the
/// simulation engine.
bool _canReachAnyReceiver(Map<String, BoardNode> nodes, GridPos start) {
  final visited = <String>{start.key};
  final queue = <GridPos>[start];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    final node = nodes[current.key];
    if (node == null) continue;
    if (node.kind == NodeKind.receiver && current != start) return true;
    for (final d in node.connections) {
      final next = d.apply(current);
      if (visited.contains(next.key)) continue;
      if (!nodes.containsKey(next.key)) continue;
      visited.add(next.key);
      queue.add(next);
    }
  }
  return false;
}

void main() {
  test('all 40 levels generate without throwing and are structurally sound', () {
    for (var id = 1; id <= 40; id++) {
      final level = LevelGenerator.generate(id);
      expect(level.rows, greaterThan(0));
      expect(level.cols, greaterThan(0));
      expect(level.starts, isNotEmpty, reason: 'level $id has no starts');
      expect(level.receivers, isNotEmpty, reason: 'level $id has no receivers');

      for (final start in level.starts) {
        final reachable = _canReachAnyReceiver(level.nodes, start.pos);
        expect(reachable, isTrue, reason: 'level $id start ${start.pos} cannot reach any receiver');
      }

      // Every mandatory slot must correspond to a real node with the
      // expected degree characteristics.
      for (final entry in level.mandatorySlots.entries) {
        final node = level.nodes[entry.key];
        expect(node, isNotNull, reason: 'level $id missing mandatory node ${entry.key}');
        expect(node!.connections.length, greaterThanOrEqualTo(3),
            reason: 'level $id mandatory node ${entry.key} has degree ${node.connections.length}');
      }
    }
  });

  test('minimal placement (mandatory routers only) is not enough to win most levels', () {
    // This is the core anti-boredom guarantee: just wiring the *required*
    // routers and touching nothing else should fall short of the score
    // goal on the vast majority of levels, so the optional component
    // layer is never just decorative.
    var minimalWins = 0;
    final buffer = StringBuffer();
    for (var id = 1; id <= 40; id++) {
      final level = LevelGenerator.generate(id);
      final placements = <String, PlacedComponent>{};
      for (final entry in level.mandatorySlots.entries) {
        placements[entry.key] = PlacedComponent(nodeKey: entry.key, type: entry.value);
      }
      // No explicit seed - use the same default the real game applies
      // when a player launches this exact level, so the assertion below
      // reflects what will actually happen in play.
      final engine = SimulationEngine(level: level, placements: placements);
      final result = engine.runToCompletion();
      if (result.won) minimalWins++;
      buffer.writeln(
          'L$id ch${level.chapter} minimal: score=${result.score}/${level.goal.minScore} delivered=${result.delivered}/${level.goal.minDelivered} cascade=${result.cascadeCount}/${level.goal.minCascade} won=${result.won}');
    }
    // ignore: avoid_print
    print(buffer.toString());
    // A handful of boards may have too few optional slots to create a
    // meaningful gap (falls back to "guaranteed winnable"), but doing
    // nothing extra should fail on most levels.
    expect(minimalWins, lessThan(12));
  });

  test('a reasonable (not perfectly optimal) placement wins most levels with room for stars', () {
    var wins = 0;
    var star2OrMore = 0;
    final buffer = StringBuffer();
    for (var id = 1; id <= 40; id++) {
      final level = LevelGenerator.generate(id);
      final placements = <String, PlacedComponent>{};
      for (final entry in level.mandatorySlots.entries) {
        placements[entry.key] = PlacedComponent(nodeKey: entry.key, type: entry.value);
      }
      final remainingInventory = Map<ComponentType, int>.from(level.inventory);
      for (final t in level.mandatorySlots.values) {
        remainingInventory[t] = (remainingInventory[t] ?? 1) - 1;
      }
      // Mirror a reasonably savvy (but not perfectly optimized) player:
      // favor the components that most directly raise score/power first.
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
      final linearTypeOrder = priority.where((t) => (remainingInventory[t] ?? 0) > 0).toList();
      for (final key in level.optionalSlotKeys) {
        for (final type in linearTypeOrder) {
          if ((remainingInventory[type] ?? 0) > 0) {
            placements[key] = PlacedComponent(
              nodeKey: key,
              type: type,
              targetColor: type.needsColorConfig ? BallColor.white : null,
              delayTicks: 3,
            );
            remainingInventory[type] = remainingInventory[type]! - 1;
            break;
          }
        }
      }
      final engine = SimulationEngine(level: level, placements: placements);
      final result = engine.runToCompletion();
      if (result.won) wins++;
      if (result.stars >= 2) star2OrMore++;
      buffer.writeln(
          'L$id ch${level.chapter} smart: score=${result.score} min=${level.goal.minScore} star2=${level.goal.star2Score} star3=${level.goal.star3Score} stars=${result.stars} won=${result.won}');
    }
    // ignore: avoid_print
    print(buffer.toString());
    expect(wins, greaterThan(34));
    expect(star2OrMore, greaterThan(15));
  });
}
