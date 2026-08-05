enum FlowRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    FlowRoute.native => 'native',
    FlowRoute.portal => 'portal',
    FlowRoute.undecided => 'undecided',
  };

  static FlowRoute parse(String? value) => switch (value) {
    'portal' || 'web' => FlowRoute.portal,
    'native' || 'game' => FlowRoute.native,
    _ => FlowRoute.undecided,
  };
}

class ConfigReply {
  const ConfigReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory ConfigReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return ConfigReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory ConfigReply.rejected(String reason) =>
      ConfigReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class FlowTarget {
  const FlowTarget();
}

final class NativeTarget extends FlowTarget {
  const NativeTarget();
}

final class PortalTarget extends FlowTarget {
  const PortalTarget(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineTarget extends FlowTarget {
  const OfflineTarget({required this.returnToNative});

  final bool returnToNative;
}
