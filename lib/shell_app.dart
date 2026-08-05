import 'package:flutter/material.dart';

import 'app.dart';
import 'fluxgate/flow_conductor.dart';
import 'fluxgate/launch_gate_screen.dart';

/// Root of the app. Mounts the flux launch gate, which decides between the
/// WebView (gray) and the Radiant Drop Path game (white / organic).
class RadiantShellApp extends StatelessWidget {
  const RadiantShellApp({super.key, this.conductor});

  final FlowConductor? conductor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radiant Drop Path',
      debugShowCheckedModeBanner: false,
      home: LaunchGateScreen(
        conductor: conductor,
        // Organic path: the gate already served the loading UX, so start the
        // game at its main menu (avoids a double loading screen).
        gameBuilder: (_) =>
            const RadiantDropPathApp(initialRoute: Routes.mainMenu),
      ),
    );
  }
}
