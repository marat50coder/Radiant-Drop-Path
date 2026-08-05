import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fluxgate/config/radiant_config.dart';
import 'fluxgate/flow_conductor.dart';
import 'fluxgate/infra/config_courier.dart';
import 'fluxgate/infra/drop_vault.dart';
import 'fluxgate/infra/link_probe.dart';
import 'fluxgate/infra/masked_agent.dart';
import 'fluxgate/infra/pulse_beacon.dart';
import 'fluxgate/infra/trace_signals.dart';
import 'services/audio_service.dart';
import 'services/save_service.dart';
import 'shell_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vault = DropVault();
  final agent = MaskedAgent();
  await Future.wait<void>(<Future<void>>[
    // White-part game services — initialised before runApp so the organic
    // path can jump straight to the main menu without re-loading.
    SaveService.instance.init(),
    AudioService.instance.init(),
    vault.initialize(),
    agent.prepare(),
  ]);

  assert(() {
    debugPrint(
      '[RDX.BOOT] credentialsReady=${RadiantConfig.grayCredentialsReady} '
      'endpoint=${RadiantConfig.endpoint} '
      'afKeyLen=${RadiantConfig.appsFlyerKey.length} '
      'fbNum=${RadiantConfig.firebaseProjectNumber}',
    );
    return true;
  }());

  var productionServicesReady = false;
  if (RadiantConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
      assert(() {
        debugPrint('[RDX.BOOT] Firebase.initializeApp OK');
        return true;
      }());
    } catch (error) {
      assert(() {
        debugPrint('[RDX.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never block FCM / gray routing.
        assert(() {
          debugPrint('[RDX.BOOT] AppCheck skipped: $error');
          return true;
        }());
      }
    }
  } else {
    assert(() {
      debugPrint(
        '[RDX.BOOT] gray gate DISABLED — missing credentials. Game only.',
      );
      return true;
    }());
  }

  final probe = LinkProbe();
  // Attribution + config POST must run even if Firebase failed to init; only
  // push/FCM needs productionServicesReady.
  final beacon = PulseBeacon(vault, enabled: productionServicesReady);
  final attribution = TraceSignals(agent);
  final conductor = FlowConductor(
    vault: vault,
    probe: probe,
    attribution: attribution,
    courier: ConfigCourier(agent, vault),
    beacon: beacon,
    agent: agent,
    runtimeEnabled: RadiantConfig.grayCredentialsReady,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(RadiantShellApp(conductor: conductor));
}
