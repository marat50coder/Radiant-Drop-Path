import 'package:flutter/material.dart';
import '../models/component_type.dart';
import '../theme/app_colors.dart';
import '../utils/asset_paths.dart';

class ComponentPalette extends StatelessWidget {
  final Map<ComponentType, int> remaining;
  final ComponentType? selected;
  final void Function(ComponentType type) onSelect;
  final void Function(ComponentType type)? onInfo;

  const ComponentPalette({
    super.key,
    required this.remaining,
    required this.selected,
    required this.onSelect,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final types = remaining.keys.toList()..sort((a, b) => a.unlockChapter.compareTo(b.unlockChapter));
    if (types.isEmpty) {
      return const SizedBox(
        height: 92,
        child: Center(
          child: Text('No optional components on this board - just wire it up!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      );
    }
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: types.length,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final type = types[i];
          final count = remaining[type] ?? 0;
          final isSelected = selected == type;
          final enabled = count > 0;
          return GestureDetector(
            onTap: enabled ? () => onSelect(type) : null,
            onLongPress: () => onInfo?.call(type),
            child: Opacity(
              opacity: enabled ? 1 : 0.35,
              child: Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.18) : AppColors.panelLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? AppColors.accentCyan : AppColors.gridLine, width: isSelected ? 2 : 1),
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 34,
                          child: Image.asset(AssetPaths.componentIcon(type, 0), fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 3),
                        Text(type.shortTag,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w800),
                            maxLines: 1),
                        Text('x$count', style: const TextStyle(color: AppColors.accentGold, fontSize: 10), maxLines: 1),
                      ],
                    ),
                    if (type.isRouter)
                      Positioned(
                        top: 0,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 2,
                      child: Icon(Icons.info_outline, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
