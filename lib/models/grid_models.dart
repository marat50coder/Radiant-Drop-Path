/// Basic grid geometry primitives shared by the level generator, the
/// simulation engine and the board rendering widget.
class GridPos {
  final int row;
  final int col;
  const GridPos(this.row, this.col);

  String get key => '${row}_$col';

  @override
  bool operator ==(Object other) => other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 10007 + col;

  @override
  String toString() => 'GridPos($row,$col)';
}

enum Direction { up, down, left, right }

extension DirectionX on Direction {
  Direction get opposite {
    switch (this) {
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
      case Direction.left:
        return Direction.right;
      case Direction.right:
        return Direction.left;
    }
  }

  GridPos apply(GridPos p) {
    switch (this) {
      case Direction.up:
        return GridPos(p.row - 1, p.col);
      case Direction.down:
        return GridPos(p.row + 1, p.col);
      case Direction.left:
        return GridPos(p.row, p.col - 1);
      case Direction.right:
        return GridPos(p.row, p.col + 1);
    }
  }
}

/// The structural role a board node plays before any component is placed.
enum NodeKind {
  start,
  receiver,
  wire, // degree <= 2, plain track, no slot available
  optionalSlot, // degree <= 2, player may place an enhancement component
  mandatoryRouter, // degree >= 3, player must place a divider/intersection
}

/// A single node of the level's circuit graph, positioned on the grid.
class BoardNode {
  final GridPos pos;
  final NodeKind kind;
  final Set<Direction> connections;

  /// Only set when [kind] is [NodeKind.mandatoryRouter]: which component
  /// type structurally fits this junction (divider for tree branches,
  /// intersection for clean lane crossings).
  final bool isCrossing;

  /// Index into the level's start/receiver spec lists, when applicable.
  final int? specIndex;

  /// For wire/optionalSlot nodes: the direction that continues *forward*
  /// along this node's lane/branch, away from its Start and toward its
  /// Receiver. Set once at generation time from the original carved
  /// path, so Teleport (and anything else that needs to "keep moving
  /// forward" from an arbitrary node) never has to guess and can never
  /// send a sphere back toward a dead end near its own Start.
  final Direction? forwardDir;

  const BoardNode({
    required this.pos,
    required this.kind,
    required this.connections,
    this.isCrossing = false,
    this.specIndex,
    this.forwardDir,
  });

  int get degree => connections.length;
}
