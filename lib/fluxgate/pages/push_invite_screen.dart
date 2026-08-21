import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/radiant_config.dart';
import '../infra/drop_vault.dart';
import '../infra/pulse_beacon.dart';

/// Push opt-in promo, shown before the WebView on first entry into gray mode.
class PushInviteScreen extends StatefulWidget {
  const PushInviteScreen({
    super.key,
    required this.vault,
    required this.beacon,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final DropVault vault;
  final PulseBeacon beacon;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<PushInviteScreen> createState() => _PushInviteScreenState();
}

class _PushInviteScreenState extends State<PushInviteScreen> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The launch gate locks portrait before routing here; re-enable landscape
    // so this screen rotates with the device (matches the WebView).
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.beacon.askPermission();
    final token = widget.beacon.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        RadiantConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/pulse_prompt_landscape.webp'
        : 'assets/pulse_prompt_portrait.webp';
    // Landscape: centred horizontally with NO safe-area so the notch never
    // shifts the horizontal centre.
    final width = landscape
        ? (media.size.width * 0.42).clamp(320.0, 560.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);
    final acceptH = landscape ? 66.0 : 74.0;
    final skipH = landscape ? 58.0 : 64.0;
    final acceptFont = landscape ? 22.0 : 25.0;
    final skipFont = landscape ? 20.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.80 : 0.90),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _InviteButton(
                  width: width,
                  height: acceptH,
                  fontSize: acceptFont,
                  label: 'Accept',
                  emphasized: true,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 12 : 16),
                _InviteButton(
                  width: width * 0.9,
                  height: skipH,
                  fontSize: skipFont,
                  label: 'Skip',
                  emphasized: false,
                  busy: false,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFF57E6FF), Color(0xFF3A7BFF)]
                : const <Color>[Color(0xFF5A6478), Color(0xFF3A4256)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF0A1830), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
