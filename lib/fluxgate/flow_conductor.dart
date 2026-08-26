import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'config/radiant_config.dart';
import 'core/flux_models.dart';
import 'infra/cold_tap_reader.dart';
import 'infra/config_courier.dart';
import 'infra/drop_vault.dart';
import 'infra/link_probe.dart';
import 'infra/masked_agent.dart';
import 'infra/pulse_beacon.dart';
import 'infra/trace_signals.dart';

/// The whole routing brain: cold-start push first, then the fresh /
/// returning-portal / returning-native pipelines. Decides between the game
/// (white) and the WebView (gray) from AppsFlyer attribution + backend.
class FlowConductor {
  FlowConductor({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.courier,
    required this.beacon,
    required this.agent,
    required this.runtimeEnabled,
  });

  final DropVault vault;
  final LinkProbe probe;
  final TraceSignals attribution;
  final ConfigCourier courier;
  final PulseBeacon beacon;
  final MaskedAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && RadiantConfig.grayCredentialsReady;

  Future<FlowTarget>? _decideFuture;

  /// De-duplicates only *concurrent* calls (the boot screen can build twice
  /// at startup). The cache is cleared on completion so a later Retry from the
  /// offline screen re-runs the whole pipeline instead of replaying a cached
  /// OfflineTarget forever.
  Future<FlowTarget> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<FlowTarget> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      fluxTrace(
        () => '[RDX.FLOW] gate disabled runtime=$runtimeEnabled '
            'creds=${RadiantConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const NativeTarget();
    }

    fluxTrace(() => '[RDX.FLOW] decide start route=${vault.route}');

    beacon.onTokenChanged = _refreshForToken;
    final coldRoute = await ColdTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(FlowRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalTarget(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      FlowRoute.undecided => _firstDecision(onProgress),
      FlowRoute.portal => _returningPortal(onProgress),
      FlowRoute.native => _returningNative(onProgress),
    };
  }

  Future<FlowTarget> _firstDecision(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      fluxTrace(() => '[RDX.FLOW] first: no interface → offline');
      return const OfflineTarget(returnToNative: false);
    }
    progress(0.28);
    try {
      await beacon.boot();
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      fluxTrace(() => '[RDX.FLOW] first: DNS probe failed → offline');
      return const OfflineTarget(returnToNative: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    fluxTrace(
      () => '[RDX.FLOW] first: config hasDest=${reply.hasDestination} '
          'url=${reply.url}',
    );
    if (reply.hasDestination) {
      await vault.saveRoute(FlowRoute.portal);
      return PortalTarget(reply.url!);
    }
    await vault.saveRoute(FlowRoute.native);
    return const NativeTarget();
  }

  Future<FlowTarget> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineTarget(returnToNative: false);
    }
    // Boot beacon *before* consuming the push URL. FirebaseMessaging's
    // getInitialMessage() is polled inside boot(), and if SceneDelegate
    // missed the cold-start payload (unknown key or the app was launched
    // from a background tap that iOS routed through the FCM proxy) that's
    // where the push URL first lands in the vault. Consuming beforehand
    // would race past a valid push URL and silently fall back to the
    // (possibly stale test) cached URL.
    await Future.wait<void>(<Future<void>>[
      beacon.boot(),
      attribution.start(),
    ]);
    // A push tap always wins — it's an explicit destination the user asked for
    // and must not be overridden by whatever the backend is serving now.
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      fluxTrace(() => '[RDX.FLOW] returningPortal: push wins → $pending');
      progress(1);
      return PortalTarget(pending);
    }
    // Refresh the config on every returning-portal launch so a backend URL
    // change is picked up immediately. The cached URL is only used as an
    // offline fallback if the request fails (never as a "fast path" that would
    // pin the app to a stale endpoint).
    final cached = await vault.savedUrl();

    if (!await probe.canReachNetwork()) {
      if (cached != null && cached.isNotEmpty) {
        fluxTrace(
          () => '[RDX.FLOW] returningPortal: offline network → cached=$cached',
        );
        return PortalTarget(cached);
      }
      return const OfflineTarget(returnToNative: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) {
      fluxTrace(
        () => '[RDX.FLOW] returningPortal: backend url=${reply.url}',
      );
      return PortalTarget(reply.url!);
    }
    if (cached != null && cached.isNotEmpty) {
      fluxTrace(
        () => '[RDX.FLOW] returningPortal: no backend url → cached=$cached',
      );
      return PortalTarget(cached);
    }
    return const OfflineTarget(returnToNative: false);
  }

  Future<FlowTarget> _returningNative(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeTarget();
    }
    await Future.wait<void>(<Future<void>>[
      beacon.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeTarget();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeTarget();
    await vault.saveRoute(FlowRoute.portal);
    return PortalTarget(reply.url!);
  }

  Future<ConfigReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? beacon.token,
    );
    // DEBUG ONLY: pretend the install is Non-organic so the backend returns a
    // URL and the WebView opens — lets us verify the gray shell on a real
    // device without live AppsFlyer attribution. Never runs in release.
    if (kDebugMode && RadiantConfig.debugForcePortal) {
      body['af_status'] = 'Non-organic';
      fluxTrace(() => '[RDX.FLOW] DEBUG force portal: af_status=Non-organic');
    }
    return courier.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        beacon.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
