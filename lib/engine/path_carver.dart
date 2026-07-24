import 'dart:math';
import '../models/grid_models.dart';

/// Randomized, backtracking path finder used to carve winding circuit
/// traces on the level grid. Deterministic given the same [Random] seed
/// state, bounded in work so it always terminates quickly even on the
/// small grids used by this game (rows*cols <= ~120).
class PathCarver {
  final Random rng;
  final int rows;
  final int cols;
  final bool Function(GridPos p) isBlocked;
  final double windiness;
  final int maxExpansions;

  int _expansions = 0;

  PathCarver({
    required this.rng,
    required this.rows,
    required this.cols,
    required this.isBlocked,
    this.windiness = 0.35,
    this.maxExpansions = 6000,
  });

  bool _inBounds(GridPos p) => p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  /// Finds a winding path from [from] to [to] that avoids [isBlocked]
  /// cells (except the endpoints themselves). Returns null if no path is
  /// found within the expansion budget.
  List<GridPos>? findPath(GridPos from, GridPos to, {int maxLen = 400}) {
    _expansions = 0;
    final visited = <GridPos>{from};
    final path = <GridPos>[from];
    if (_search(path, visited, to, maxLen)) {
      return List.unmodifiable(path);
    }
    return null;
  }

  bool _search(List<GridPos> path, Set<GridPos> visited, GridPos to, int maxLen) {
    _expansions++;
    if (_expansions > maxExpansions) return false;
    final current = path.last;
    if (current == to) return true;
    if (path.length >= maxLen) return false;

    final candidates = <Direction>[Direction.up, Direction.down, Direction.left, Direction.right];
    // Bias ordering: mostly greedy-toward-target with some shuffled
    // windiness so traces are not perfectly straight lines.
    if (rng.nextDouble() < windiness) {
      candidates.shuffle(rng);
    } else {
      candidates.sort((a, b) {
        final na = a.apply(current);
        final nb = b.apply(current);
        final da = (na.row - to.row).abs() + (na.col - to.col).abs();
        final db = (nb.row - to.row).abs() + (nb.col - to.col).abs();
        return (da - db) + (rng.nextInt(3) - 1);
      });
    }

    for (final dir in candidates) {
      final next = dir.apply(current);
      if (!_inBounds(next)) continue;
      if (visited.contains(next)) continue;
      if (next != to && isBlocked(next)) continue;
      visited.add(next);
      path.add(next);
      if (_search(path, visited, to, maxLen)) return true;
      path.removeLast();
      visited.remove(next);
      if (_expansions > maxExpansions) return false;
    }
    return false;
  }
}

Direction directionBetween(GridPos a, GridPos b) {
  if (b.row == a.row - 1 && b.col == a.col) return Direction.up;
  if (b.row == a.row + 1 && b.col == a.col) return Direction.down;
  if (b.col == a.col - 1 && b.row == a.row) return Direction.left;
  if (b.col == a.col + 1 && b.row == a.row) return Direction.right;
  throw ArgumentError('Cells $a and $b are not orthogonally adjacent');
}
