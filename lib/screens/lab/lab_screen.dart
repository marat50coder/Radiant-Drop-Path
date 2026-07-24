import 'package:flutter/material.dart';
import '../../models/component_type.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/asset_paths.dart';
import '../../utils/sound_paths.dart';
import '../../widgets/resource_chip.dart';

/// Engineering Lab: resource overview + cosmetic skin gallery. Purely
/// cosmetic - unlocking/selecting a skin never changes gameplay, only
/// how that component looks on the board.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  ComponentType _selectedType = ComponentType.amplifier;

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Engineering Lab')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ResourceChip(icon: Icons.diamond, color: AppColors.accentCyan, value: save.crystals),
                ResourceChip(icon: Icons.memory, color: AppColors.accentGold, value: save.microParts),
                ResourceChip(icon: Icons.developer_board, color: AppColors.accentMagenta, value: save.processors),
                ResourceChip(icon: Icons.bolt, color: AppColors.success, value: save.xp),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Component Skins',
              style: titleGlow(size: 16),
            ),
          ),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: ComponentType.values.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final type = ComponentType.values[i];
                final selected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    width: 68,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accentCyan.withValues(alpha: 0.2) : AppColors.panelLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.accentCyan : AppColors.gridLine),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: Image.asset(AssetPaths.componentIcon(type, save.skinFor(type)), fit: BoxFit.contain)),
                        Text(type.shortTag, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: AppColors.gridLine, height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _selectedType.skinCount,
              itemBuilder: (context, skin) {
                final unlocked = save.isSkinUnlocked(_selectedType, skin);
                final selected = save.skinFor(_selectedType) == skin;
                final cost = 12 + skin * 6;
                return GestureDetector(
                  onTap: () async {
                    AudioService.instance.playSfx(SoundPaths.buttonClick);
                    if (unlocked) {
                      await save.selectSkin(_selectedType, skin);
                      setState(() {});
                    } else {
                      final ok = await save.unlockSkin(_selectedType, skin, cost);
                      if (ok) {
                        AudioService.instance.playSfx(SoundPaths.unlockComponent);
                        await save.selectSkin(_selectedType, skin);
                      }
                      setState(() {});
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accentCyan.withValues(alpha: 0.15) : AppColors.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? AppColors.accentCyan : AppColors.gridLine, width: selected ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: unlocked ? 1 : 0.4,
                            child: Image.asset(AssetPaths.componentIcon(_selectedType, skin), fit: BoxFit.contain),
                          ),
                        ),
                        if (!unlocked)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.diamond, size: 10, color: AppColors.accentCyan),
                              const SizedBox(width: 2),
                              Text('$cost', style: const TextStyle(fontSize: 10, color: AppColors.accentCyan)),
                            ],
                          )
                        else if (selected)
                          const Icon(Icons.check_circle, size: 14, color: AppColors.success)
                        else
                          const SizedBox(height: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
