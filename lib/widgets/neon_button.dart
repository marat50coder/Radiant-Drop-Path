import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum NeonButtonVariant { primary, secondary, danger, ghost }
enum NeonButtonSize { large, medium, small }

/// The app's signature CTA button: gradient-filled, glowing, with a
/// tactile press-down animation. Used everywhere a player makes a real
/// decision (launch a scheme, confirm, navigate) so the whole game feels
/// like one consistent, premium circuit-board UI instead of stock
/// Material widgets.
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final NeonButtonVariant variant;
  final NeonButtonSize size;
  final bool fullWidth;
  final Color? accent;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = NeonButtonVariant.primary,
    this.size = NeonButtonSize.large,
    this.fullWidth = true,
    this.accent,
  });

  const NeonButton.primary({
    Key? key,
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    NeonButtonSize size = NeonButtonSize.large,
    bool fullWidth = true,
    Color? accent,
  }) : this(
          key: key,
          label: label,
          icon: icon,
          onPressed: onPressed,
          variant: NeonButtonVariant.primary,
          size: size,
          fullWidth: fullWidth,
          accent: accent,
        );

  const NeonButton.secondary({
    Key? key,
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    NeonButtonSize size = NeonButtonSize.large,
    bool fullWidth = true,
    Color? accent,
  }) : this(
          key: key,
          label: label,
          icon: icon,
          onPressed: onPressed,
          variant: NeonButtonVariant.secondary,
          size: size,
          fullWidth: fullWidth,
          accent: accent,
        );

  const NeonButton.danger({
    Key? key,
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    NeonButtonSize size = NeonButtonSize.large,
    bool fullWidth = true,
  }) : this(
          key: key,
          label: label,
          icon: icon,
          onPressed: onPressed,
          variant: NeonButtonVariant.danger,
          size: size,
          fullWidth: fullWidth,
        );

  const NeonButton.ghost({
    Key? key,
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    NeonButtonSize size = NeonButtonSize.medium,
    bool fullWidth = true,
  }) : this(
          key: key,
          label: label,
          icon: icon,
          onPressed: onPressed,
          variant: NeonButtonVariant.ghost,
          size: size,
          fullWidth: fullWidth,
        );

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = v);
  }

  double get _height {
    switch (widget.size) {
      case NeonButtonSize.large:
        return 58;
      case NeonButtonSize.medium:
        return 50;
      case NeonButtonSize.small:
        return 40;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case NeonButtonSize.large:
        return 16;
      case NeonButtonSize.medium:
        return 14;
      case NeonButtonSize.small:
        return 12.5;
    }
  }

  double get _radius {
    switch (widget.size) {
      case NeonButtonSize.large:
        return 18;
      case NeonButtonSize.medium:
        return 15;
      case NeonButtonSize.small:
        return 12;
    }
  }

  Color get _accent {
    if (widget.accent != null) return widget.accent!;
    switch (widget.variant) {
      case NeonButtonVariant.primary:
        return AppColors.accentCyan;
      case NeonButtonVariant.secondary:
        return AppColors.textPrimary;
      case NeonButtonVariant.danger:
        return AppColors.danger;
      case NeonButtonVariant.ghost:
        return AppColors.accentGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final accent = _accent;

    Widget content;
    BoxDecoration decoration;
    Color labelColor;

    switch (widget.variant) {
      case NeonButtonVariant.primary:
        labelColor = const Color(0xFF041017);
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withValues(alpha: 1), _deepen(accent)],
                )
              : LinearGradient(colors: [AppColors.gridLine, AppColors.gridLine]),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: _pressed ? 0.28 : 0.5),
                    blurRadius: _pressed ? 10 : 22,
                    spreadRadius: _pressed ? -2 : 0,
                    offset: Offset(0, _pressed ? 2 : 8),
                  ),
                ]
              : const [],
        );
        break;
      case NeonButtonVariant.danger:
        labelColor = const Color(0xFF1A0508);
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, _deepen(accent)],
                )
              : LinearGradient(colors: [AppColors.gridLine, AppColors.gridLine]),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: _pressed ? 0.25 : 0.45),
                    blurRadius: _pressed ? 8 : 18,
                    offset: Offset(0, _pressed ? 2 : 6),
                  ),
                ]
              : const [],
        );
        break;
      case NeonButtonVariant.secondary:
        labelColor = enabled ? AppColors.textPrimary : AppColors.textSecondary;
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: AppColors.panelLight.withValues(alpha: _pressed ? 0.7 : 0.95),
          border: Border.all(color: enabled ? AppColors.accentCyan.withValues(alpha: 0.55) : AppColors.gridLine, width: 1.4),
          boxShadow: enabled && !_pressed
              ? [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4))]
              : const [],
        );
        break;
      case NeonButtonVariant.ghost:
        labelColor = enabled ? accent : AppColors.textSecondary;
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: Colors.transparent,
          border: Border.all(color: enabled ? accent.withValues(alpha: _pressed ? 0.3 : 0.55) : AppColors.gridLine),
        );
        break;
    }
    final shadows = decoration.boxShadow ?? const [];

    content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: _fontSize + 4, color: labelColor),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w800,
            fontSize: _fontSize,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: _height,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            gradient: decoration.gradient,
            color: decoration.color,
            border: decoration.border,
            boxShadow: shadows,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  Color _deepen(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0)).withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0)).toColor();
  }
}
