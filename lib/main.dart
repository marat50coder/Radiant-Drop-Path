import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/attribution_service.dart';
import 'services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications first: registers the APNs delegate, requests
  // permission, caches the FCM token. AppsFlyer runs after so the ATT dialog
  // appears once permissions are settled. Both calls swallow their own
  // errors — the game must always boot even if remote services are down.
  await NotificationsService.instance.initialize();
  unawaited(AttributionService.instance.start());

  runApp(const RadiantDropPathApp());
}
