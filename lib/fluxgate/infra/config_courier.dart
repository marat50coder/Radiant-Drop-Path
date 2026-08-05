import 'dart:convert';

import '../config/radiant_config.dart';
import '../core/flux_models.dart';
import 'drop_vault.dart';
import 'masked_agent.dart';
import 'trace_signals.dart';

/// POSTs the flat attribution + device payload to the config endpoint and
/// parses the reply. Caches a granted URL for returning launches.
class ConfigCourier {
  ConfigCourier(this._agent, this._vault);

  final MaskedAgent _agent;
  final DropVault _vault;

  Future<ConfigReply> request(Map<String, dynamic> payload) async {
    if (!RadiantConfig.grayCredentialsReady) {
      return ConfigReply.rejected('credentials_unavailable');
    }
    try {
      fluxTrace(() => '[RDX.COURIER] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(RadiantConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      fluxTrace(
        () => '[RDX.COURIER] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return ConfigReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return ConfigReply.rejected('invalid_response');
      final reply = ConfigReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      fluxTrace(() => '[RDX.COURIER] failed: $error');
      return ConfigReply.rejected('network_failure');
    }
  }
}
