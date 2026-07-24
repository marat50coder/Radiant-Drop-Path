import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The six energy sphere colors. Order matches the collection_sphere sprite
/// sheet (skin_0..skin_5) so [assetIndex] can be used directly for icons.
enum BallColor { blue, red, green, yellow, purple, white }

extension BallColorX on BallColor {
  int get assetIndex => index;

  String get displayName {
    switch (this) {
      case BallColor.blue:
        return 'Blue';
      case BallColor.red:
        return 'Red';
      case BallColor.green:
        return 'Green';
      case BallColor.yellow:
        return 'Yellow';
      case BallColor.purple:
        return 'Purple';
      case BallColor.white:
        return 'White';
    }
  }

  Color get color {
    switch (this) {
      case BallColor.blue:
        return AppColors.ballBlue;
      case BallColor.red:
        return AppColors.ballRed;
      case BallColor.green:
        return AppColors.ballGreen;
      case BallColor.yellow:
        return AppColors.ballYellow;
      case BallColor.purple:
        return AppColors.ballPurple;
      case BallColor.white:
        return AppColors.ballWhite;
    }
  }

  /// Baseline speed multiplier (cells per tick scaling). Blue = fastest.
  double get speedMultiplier {
    switch (this) {
      case BallColor.blue:
        return 1.35;
      default:
        return 1.0;
    }
  }

  /// Power multiplier applied to the ball's base power value.
  double get powerMultiplier {
    switch (this) {
      case BallColor.red:
        return 1.6;
      default:
        return 1.0;
    }
  }

  /// Score value multiplier applied when the ball is delivered.
  double get scoreMultiplier {
    switch (this) {
      case BallColor.red:
        return 1.3;
      case BallColor.purple:
        return 1.4;
      default:
        return 1.0;
    }
  }

  /// Red balls carry enough energy to trigger high-power-only components.
  bool get isHighPower => this == BallColor.red;

  /// Green balls may travel on color-restricted alternate edges.
  bool get canUseAlternatePaths => this == BallColor.green || this == BallColor.white;

  /// Yellow balls can trigger dormant generators.
  bool get canTriggerGenerator => this == BallColor.yellow || this == BallColor.white;

  /// Purple balls energize rare components (resonator / teleport bonus).
  bool get isRareEnergizer => this == BallColor.purple || this == BallColor.white;

  /// Short description used in the codex / tutorial popups.
  String get description {
    switch (this) {
      case BallColor.blue:
        return 'Fastest sphere. Ideal for long routes and racing the clock.';
      case BallColor.red:
        return 'High-energy sphere. Activates power-hungry components and scores extra.';
      case BallColor.green:
        return 'Can travel rare alternate paths closed to other colors.';
      case BallColor.yellow:
        return 'Unstable and generous - can awaken dormant Generators.';
      case BallColor.purple:
        return 'Resonates with rare tech - required to energize some components.';
      case BallColor.white:
        return 'Universal sphere. Works acceptably with every component.';
    }
  }
}
