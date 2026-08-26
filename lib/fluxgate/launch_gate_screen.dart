import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/asset_paths.dart';
import 'core/flux_models.dart';
import 'flow_conductor.dart';
import 'infra/trace_signals.dart' show fluxTrace;
import 'pages/beam_portal.dart';
import 'pages/no_link_screen.dart';
import 'pages/push_invite_screen.dart';

/// Splash + gray/white routing point. Plays the loading art while
/// [FlowConductor.decide] runs the attribution → config pipeline, then routes
/// to the WebView (gray), the game (organic) or the offline screen.
///
/// The [gameBuilder] returns the white-part entry so this layer never hard
/// depends on the game code.
class LaunchGateScreen extends StatefulWidget {
  const LaunchGateScreen({
    super.key,
    required this.gameBuilder,
    this.conductor,
  });

  final WidgetBuilder gameBuilder;
  final FlowConductor? conductor;

  @override
  State<LaunchGateScreen> createState() => _LaunchGateScreenState();
}

class _LaunchGateScreenState extends State<LaunchGateScreen> {
  double _flowProgress = 0;
  FlowTarget? _target;
  bool _started = false;
  bool _navigating = false;
  late final DateTime _startTime;
  Timer? _hardDeadline;
  static const Duration _minSplash = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Safety net only. The conductor's own timeouts (probe/apns/attribution/
    // config) already bound decide() well under this window, so on a normal
    // first launch decide() always wins the race. If a native plugin truly
    // hangs, fall back to the offline/retry screen when the gray gate is on
    // (never silently commit to the game — that would break the first-launch
    // invariant), otherwise straight to the game.
    _hardDeadline = Timer(const Duration(seconds: 30), () {
      if (!mounted || _navigating || _target != null) return;
      final conductor = widget.conductor;
      _target = (conductor != null && conductor.enabled)
          ? const OfflineTarget(returnToNative: false)
          : const NativeTarget();
      fluxTrace(() => '[RDX.GATE] hard-deadline fired -> $_target');
      _maybeNavigate();
    });
  }

  @override
  void dispose() {
    _hardDeadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolveTarget();
    }
  }

  Future<void> _resolveTarget() async {
    final conductor = widget.conductor;
    if (conductor == null) {
      _target = const NativeTarget();
      _flowProgress = 1;
      _maybeNavigate();
      return;
    }
    try {
      _target = await conductor.decide(
        onProgress: (value) {
          if (mounted) setState(() => _flowProgress = value.clamp(0.0, 1.0));
        },
      );
    } catch (_) {
      _target = const NativeTarget();
    }
    if (mounted) setState(() => _flowProgress = 1);
    _hardDeadline?.cancel();
    fluxTrace(() => '[RDX.GATE] decide resolved -> $_target');
    _maybeNavigate();
  }

  void _maybeNavigate() async {
    if (_navigating || _target == null) return;
    final elapsed = DateTime.now().difference(_startTime);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }
    if (!mounted || _navigating) return;
    _navigating = true;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    await _openTarget(_target!);
  }

  Future<void> _openTarget(FlowTarget target) async {
    final conductor = widget.conductor;
    fluxTrace(() => '[RDX.GATE] open target=$target');

    if (target is NativeTarget || conductor == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.gameBuilder),
      );
      return;
    }

    if (target is OfflineTarget) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NoLinkScreen(
            probe: conductor.probe,
            retryBuilder: (_) => LaunchGateScreen(
              gameBuilder: widget.gameBuilder,
              conductor: conductor,
            ),
          ),
        ),
      );
      return;
    }

    if (target is PortalTarget) {
      Widget portalBuilder(BuildContext _) => BeamPortal(
        url: target.url,
        coldLaunch: target.coldLaunch,
        vault: conductor.vault,
        probe: conductor.probe,
        beacon: conductor.beacon,
        agent: conductor.agent,
      );

      void openPortal() {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
      }

      final offerPush = conductor.vault.shouldShowPushInvite &&
          await conductor.beacon.canOfferPermission();
      fluxTrace(
        () => '[RDX.GATE] portal -> ${offerPush ? "push-invite" : "webview"}',
      );
      if (offerPush) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PushInviteScreen(
              vault: conductor.vault,
              beacon: conductor.beacon,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        openPortal();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final asset =
        isLandscape ? AssetPaths.horizontalLoading : AssetPaths.verticalLoading;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFF060A14)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLandscape ? 18 : 54),
                child: _FlowBar(
                  progress: _flowProgress,
                  width: isLandscape ? screenW * 0.42 : screenW * 0.74,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowBar extends StatelessWidget {
  const _FlowBar({required this.progress, required this.width});

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2B4A6E), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      widthFactor: value <= 0 ? 0.001 : value,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF57E6FF),
                              Color(0xFF56A8FF),
                              Color(0xFF9B7CFF),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LoadingLabel(),
      ],
    );
  }
}

class _LoadingLabel extends StatefulWidget {
  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final phase = (_ctrl.value * 3).floor() % 3;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Loading',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i <= phase ? 1.0 : 0.3,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
