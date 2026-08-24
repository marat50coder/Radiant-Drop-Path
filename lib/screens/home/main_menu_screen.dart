import 'package:flutter/material.dart';
import '../../app.dart';
import '../../engine/level_generator.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/asset_paths.dart';
import '../../utils/sound_paths.dart';
import '../../widgets/player_level_badge.dart';
import '../../widgets/resource_chip.dart';
import '../webview/simple_webview_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    AudioService.instance.playMusic(SoundPaths.gameplaySoundtrack);
  }

  void _tap() => AudioService.instance.playSfx(SoundPaths.buttonClick);

  void _go(String route) {
    _tap();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final save = SaveService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AssetPaths.chapterBackground(1), fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.55),
                  AppColors.background.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ResourceChip(icon: Icons.diamond, color: AppColors.accentCyan, value: save.crystals),
                      ResourceChip(icon: Icons.memory, color: AppColors.accentGold, value: save.microParts),
                      ResourceChip(icon: Icons.developer_board, color: AppColors.accentMagenta, value: save.processors),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PlayerLevelBadge(save: save),
                  const Spacer(flex: 3),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.35), blurRadius: 50, spreadRadius: 4),
                      ],
                    ),
                    child: Image.asset(AssetPaths.gameLogo, width: 260),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'DESIGN IT · LAUNCH IT · WATCH IT CASCADE',
                    style: TextStyle(
                      color: AppColors.accentCyan.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const Spacer(flex: 4),
                  _HeroPlayButton(
                    subtitle: '${LevelGenerator.totalLevels} levels of cascade puzzles',
                    onPressed: () => _go(Routes.levelSelect),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MenuTile(
                          label: 'ENDLESS',
                          subtitle: 'Infinite run',
                          icon: Icons.all_inclusive,
                          accent: AppColors.accentCyan,
                          onPressed: () => _go(Routes.endless),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MenuTile(
                          label: 'LAB',
                          subtitle: 'Experiment',
                          icon: Icons.science_outlined,
                          accent: AppColors.accentMagenta,
                          onPressed: () => _go(Routes.lab),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MenuTile(
                          label: 'GUIDE',
                          subtitle: 'Field manual',
                          icon: Icons.menu_book_outlined,
                          accent: AppColors.accentGold,
                          onPressed: () => _go(Routes.guide),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MenuTile(
                          label: 'SETTINGS',
                          subtitle: 'Tune & audio',
                          icon: Icons.settings_outlined,
                          accent: AppColors.success,
                          onPressed: () => _go(Routes.settings),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _FooterButton(
                          label: 'Privacy Policy',
                          icon: Icons.shield_outlined,
                          accent: AppColors.accentCyan,
                          onPressed: () => _openLegal(
                            'Privacy Policy',
                            'https://radiantdroppath.com/privacy-policy.html',
                            true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FooterButton(
                          label: 'Support',
                          icon: Icons.support_agent_outlined,
                          accent: AppColors.accentGold,
                          onPressed: () => _openLegal(
                            'Support',
                            'https://radiantdroppath.com/support.html',
                            false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLegal(String title, String url, bool whiteBg) {
    _tap();
    Navigator.of(context).pushNamed(
      Routes.webview,
      arguments: WebViewArgs(url: url, title: title, whiteBackground: whiteBg),
    );
  }
}

/// Compact framed footer button used for Privacy / Support entries.
/// Content (icon + label) is horizontally centered inside the frame.
class _FooterButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  const _FooterButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.panelLight.withValues(alpha: _pressed ? 0.65 : 0.9),
                AppColors.panel.withValues(alpha: 0.85),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: _pressed ? 0.35 : 0.55),
              width: 1.2,
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(widget.icon, size: 15, color: accent),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signature call-to-action on the menu: a wide gradient panel with a
/// breathing neon glow, a circular play badge and a supporting subtitle.
class _HeroPlayButton extends StatefulWidget {
  final String subtitle;
  final VoidCallback onPressed;
  const _HeroPlayButton({required this.subtitle, required this.onPressed});

  @override
  State<_HeroPlayButton> createState() => _HeroPlayButtonState();
}

class _HeroPlayButtonState extends State<_HeroPlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accentCyan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = 0.35 + _pulse.value * 0.35;
            return Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3EEBFF), Color(0xFF128FB8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: _pressed ? 0.25 : glow),
                    blurRadius: _pressed ? 14 : 30,
                    spreadRadius: _pressed ? -4 : 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF041017), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PLAY CAMPAIGN',
                      style: TextStyle(
                        color: Color(0xFF041017),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: const Color(0xFF041017).withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF041017), size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glassy accented feature tile used for the secondary menu actions.
class _MenuTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  const _MenuTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.panelLight.withValues(alpha: _pressed ? 0.7 : 0.95),
                AppColors.panel.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: _pressed ? 0.35 : 0.6), width: 1.4),
            boxShadow: _pressed
                ? const []
                : [BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent.withValues(alpha: 0.9), accent.withValues(alpha: 0.35)],
                  ),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: Icon(widget.icon, color: const Color(0xFF06101E), size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
