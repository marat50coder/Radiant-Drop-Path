import 'package:flutter/material.dart';
import '../../models/ball_color.dart';
import '../../models/component_type.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/asset_paths.dart';

/// The in-app "Field Guide": how the game works, what every component
/// does mechanically, and what each sphere color is good for. Reachable
/// from the main menu, level select, and mid-design via the HUD info
/// button, so help is never more than one tap away.
class GuideScreen extends StatefulWidget {
  final int initialTab;
  const GuideScreen({super.key, this.initialTab = 0});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Field Guide'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentCyan,
          tabs: const [
            Tab(text: 'How To Play'),
            Tab(text: 'Components'),
            Tab(text: 'Spheres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HowToPlayTab(),
          _ComponentsTab(),
          _SpheresTab(),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> lines;
  const _SectionCard({required this.title, required this.icon, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: titleGlow(size: 16))),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5, right: 8),
                    child: Icon(Icons.circle, size: 5, color: AppColors.accentGold),
                  ),
                  Expanded(
                    child: Text(line, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HowToPlayTab extends StatelessWidget {
  const _HowToPlayTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: const [
        _SectionCard(
          title: '1. The Goal',
          icon: Icons.flag_outlined,
          lines: [
            'Every level gives you a fixed circuit board with Start points and Receivers already wired together.',
            'Your job: engineer the wiring by placing components, then launch the scheme and watch the spheres flow.',
            'Hit the score target (and delivery/cascade targets on later chapters) before the tick budget runs out to win.',
          ],
        ),
        _SectionCard(
          title: '2. Design Phase',
          icon: Icons.build_outlined,
          lines: [
            'Tap a component in the bottom tray to select it, then tap a highlighted slot on the board to place it.',
            'Tap a placed component again to remove it and return it to your inventory.',
            'Long-press any tray icon at any time to re-read exactly what it does.',
          ],
        ),
        _SectionCard(
          title: '3. Mandatory Routers',
          icon: Icons.warning_amber_rounded,
          lines: [
            'Junctions with 3+ connections (marked with a small red dot in the tray) MUST get their exact required '
                'component - a Divider for branch points, an Intersection for clean crossings.',
            'You cannot launch until every mandatory router slot is filled - the button at the bottom tells you what\'s left.',
          ],
        ),
        _SectionCard(
          title: '4. Optional Slots - Where Strategy Lives',
          icon: Icons.auto_awesome_outlined,
          lines: [
            'Plain wire nodes can optionally host an Amplifier, Resonator, Magnet, Delay, Accelerator, Color Converter, '
                'Teleport or Generator from your limited inventory.',
            'Just wiring the mandatory routers and doing nothing else is almost never enough to hit the score target - '
                'these optional components are where the real points come from.',
            'You never have enough pieces to fill every slot, so choosing WHERE to spend them is the whole puzzle.',
          ],
        ),
        _SectionCard(
          title: '5. Launch & Simulate',
          icon: Icons.play_circle_outline,
          lines: [
            'Once every mandatory slot is filled, tap LAUNCH SCHEME. From this point the layout is locked.',
            'Spheres spawn automatically and move on their own - tap the speed chip (top-right) to speed up playback, '
                'or hit the fast-forward button to skip straight to the result.',
          ],
        ),
        _SectionCard(
          title: '6. Stars & Scoring',
          icon: Icons.star_outline_rounded,
          lines: [
            '1 star: you cleared the minimum score, delivery and cascade targets.',
            '2-3 stars: your score climbed well past the minimum - usually only possible by combining several '
                'optional components (Resonators synced with Delays, Magnet clusters, well-placed Amplifiers...).',
            'There is no single perfect layout for every level - experiment, and check the Components tab for ideas.',
          ],
        ),
      ],
    );
  }
}

class _ComponentsTab extends StatelessWidget {
  const _ComponentsTab();

  @override
  Widget build(BuildContext context) {
    final types = List<ComponentType>.from(ComponentType.values)
      ..sort((a, b) => a.unlockChapter.compareTo(b.unlockChapter));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: types.length,
      itemBuilder: (context, i) => _ComponentCard(type: types[i]),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  final ComponentType type;
  const _ComponentCard({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: type.isRouter ? AppColors.danger.withValues(alpha: 0.5) : AppColors.gridLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.panelLight, borderRadius: BorderRadius.circular(12)),
                child: Image.asset(AssetPaths.componentIcon(type, 0), fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.displayName, style: titleGlow(size: 16)),
                    const SizedBox(height: 2),
                    Text(type.description,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag(type.isRouter ? 'Mandatory router' : 'Optional slot', type.isRouter ? AppColors.danger : AppColors.success),
              _tag('Chapter ${type.unlockChapter + 1}+', AppColors.accentGold),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.gridLine, height: 1),
          const SizedBox(height: 10),
          for (final line in type.mechanics)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Icon(Icons.bolt, size: 13, color: AppColors.accentCyan),
                  ),
                  Expanded(
                    child: Text(line, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _SpheresTab extends StatelessWidget {
  const _SpheresTab();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: BallColor.values.length,
      itemBuilder: (context, i) => _SphereCard(color: BallColor.values[i]),
    );
  }
}

class _SphereCard extends StatelessWidget {
  final BallColor color;
  const _SphereCard({required this.color});

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (color.speedMultiplier != 1.0) '${color.speedMultiplier.toStringAsFixed(2)}x speed',
      if (color.powerMultiplier != 1.0) '${color.powerMultiplier.toStringAsFixed(1)}x power',
      if (color.scoreMultiplier != 1.0) '${color.scoreMultiplier.toStringAsFixed(1)}x score',
      if (color.isHighPower) 'High power',
      if (color.canTriggerGenerator) 'Wakes Generators',
      if (color.canUseAlternatePaths) 'Alternate paths',
      if (color.isRareEnergizer) 'Rare energizer (Resonator/Teleport bonus)',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gridLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.color,
              boxShadow: [BoxShadow(color: color.color.withValues(alpha: 0.6), blurRadius: 12)],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(color.displayName, style: titleGlow(size: 16, color: color.color)),
                const SizedBox(height: 4),
                Text(color.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.3)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final t in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.color.withValues(alpha: 0.55)),
                        ),
                        child: Text(t, style: TextStyle(color: color.color, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
