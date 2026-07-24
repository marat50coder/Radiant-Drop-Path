import 'ball_color.dart';
import 'component_type.dart';

/// A component the player has placed on a board node during the design
/// phase. Immutable snapshot copied into the simulation when launched.
class PlacedComponent {
  final String nodeKey;
  final ComponentType type;
  final int skinIndex;
  final BallColor? targetColor; // colorConverter configuration
  final int delayTicks; // delay configuration

  const PlacedComponent({
    required this.nodeKey,
    required this.type,
    this.skinIndex = 0,
    this.targetColor,
    this.delayTicks = 4,
  });

  PlacedComponent copyWith({BallColor? targetColor, int? delayTicks, int? skinIndex}) {
    return PlacedComponent(
      nodeKey: nodeKey,
      type: type,
      skinIndex: skinIndex ?? this.skinIndex,
      targetColor: targetColor ?? this.targetColor,
      delayTicks: delayTicks ?? this.delayTicks,
    );
  }
}
