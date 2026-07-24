import 'package:flutter/material.dart';
import '../engine/simulation_engine.dart';
import '../models/grid_models.dart';
import '../models/level.dart';
import '../models/placed_component.dart';
import '../theme/app_colors.dart';
import '../utils/asset_paths.dart';

/// A lightweight snapshot of a single sphere's current render position,
/// rebuilt every animation frame from the live [SimulationEngine].
class BallRenderInfo {
  final Offset position; // in cell-units (not pixels)
  final Color color;
  final String iconAsset;
  const BallRenderInfo({required this.position, required this.color, required this.iconAsset});
}

class BoardView extends StatelessWidget {
  final LevelDefinition level;
  final Map<String, PlacedComponent> placements;
  final double cellSize;
  final List<BallRenderInfo> balls;
  final void Function(String nodeKey)? onSlotTap;
  final String? highlightedSlot;
  final Set<String> flashingNodes;

  const BoardView({
    super.key,
    required this.level,
    required this.placements,
    required this.cellSize,
    this.balls = const [],
    this.onSlotTap,
    this.highlightedSlot,
    this.flashingNodes = const {},
  });

  @override
  Widget build(BuildContext context) {
    final width = level.cols * cellSize;
    final height = level.rows * cellSize;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _TrackPainter(level: level, cellSize: cellSize, flashingNodes: flashingNodes),
          ),
          for (final entry in level.nodes.entries) _buildNodeWidget(context, entry.key, entry.value),
          for (final ball in balls) _buildBall(ball),
        ],
      ),
    );
  }

  Offset _cellCenter(GridPos p) => Offset((p.col + 0.5) * cellSize, (p.row + 0.5) * cellSize);

  Widget _buildBall(BallRenderInfo ball) {
    final center = Offset(ball.position.dx * cellSize, ball.position.dy * cellSize);
    final size = cellSize * 0.42;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: ball.color.withValues(alpha: 0.85), blurRadius: size * 0.5)],
        ),
        child: Image.asset(ball.iconAsset, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildNodeWidget(BuildContext context, String key, BoardNode node) {
    final center = _cellCenter(node.pos);
    final placed = placements[key];
    final isSlot = node.kind == NodeKind.optionalSlot || node.kind == NodeKind.mandatoryRouter;
    final size = cellSize * (node.kind == NodeKind.start || node.kind == NodeKind.receiver ? 0.86 : 0.72);
    Widget child;

    if (node.kind == NodeKind.start) {
      child = Image.asset(AssetPaths.startPointIcon(), fit: BoxFit.contain);
    } else if (node.kind == NodeKind.receiver) {
      child = Image.asset(AssetPaths.receiverIcon(), fit: BoxFit.contain);
    } else if (placed != null) {
      child = Image.asset(AssetPaths.componentIcon(placed.type, placed.skinIndex), fit: BoxFit.contain);
    } else if (node.kind == NodeKind.mandatoryRouter) {
      final requiredType = level.mandatorySlots[key];
      child = Opacity(
        opacity: 0.55,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (requiredType != null) Image.asset(AssetPaths.componentIcon(requiredType, 0), fit: BoxFit.contain),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.danger, width: 2),
              ),
            ),
          ],
        ),
      );
    } else if (node.kind == NodeKind.optionalSlot) {
      child = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.25),
          border: Border.all(color: AppColors.gridLine, width: 1.4),
        ),
        child: Icon(Icons.add, size: size * 0.5, color: AppColors.textSecondary.withValues(alpha: 0.6)),
      );
    } else {
      child = const SizedBox.shrink();
    }

    final flashing = flashingNodes.contains(key);
    final highlighted = highlightedSlot == key;

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: isSlot && onSlotTap != null ? () => onSlotTap!(key) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (flashing) BoxShadow(color: AppColors.accentGold.withValues(alpha: 0.9), blurRadius: size * 0.6),
              if (highlighted) BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.9), blurRadius: size * 0.5),
            ],
            border: highlighted ? Border.all(color: AppColors.accentCyan, width: 2) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  final LevelDefinition level;
  final double cellSize;
  final Set<String> flashingNodes;
  _TrackPainter({required this.level, required this.cellSize, required this.flashingNodes});

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = AppColors.gridLine.withValues(alpha: 0.85)
      ..strokeWidth = cellSize * 0.12
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = AppColors.accentCyan.withValues(alpha: 0.28)
      ..strokeWidth = cellSize * 0.28
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    Offset center(GridPos p) => Offset((p.col + 0.5) * cellSize, (p.row + 0.5) * cellSize);

    for (final node in level.nodes.values) {
      final c1 = center(node.pos);
      for (final dir in node.connections) {
        final neighborPos = dir.apply(node.pos);
        // Draw each edge once (canonical direction only).
        if (dir != Direction.right && dir != Direction.down) continue;
        final c2 = center(neighborPos);
        canvas.drawLine(c1, c2, glowPaint);
        canvas.drawLine(c1, c2, basePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.cellSize != cellSize || oldDelegate.flashingNodes != flashingNodes;
}
