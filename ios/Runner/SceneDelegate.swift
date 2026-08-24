import Flutter
import UIKit
import UserNotifications

/// Captures a cold-start push tap (app killed) that iOS delivers through the
/// scene connection — NOT Firebase's swizzled path. The destination URL is
/// written to UserDefaults under `flutter.rdp_tap_route`, which the Dart side
/// reads via SharedPreferences (ColdTapReader).
class SceneDelegate: FlutterSceneDelegate {
  static let launchRouteKey = "flutter.rdp_tap_route"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let destination = Self.destination(
        inside: response.notification.request.content.userInfo
      )
    else { return }

    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.launchRouteKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[RDX.ROUTE] captured notification destination")
    #endif
  }

  /// Wide net of keys the config backend / Firebase / AppsFlyer / partner
  /// systems use for the destination URL. First key that resolves to a valid
  /// http(s) URL wins. Anything else (non-URL tokens like `deep_link_test`,
  /// campaign labels, missing values) is skipped so we never seed the vault
  /// with a garbage destination that later resolves to a stale test URL.
  private static let candidateKeys: [String] = [
    // Config backend / partner conventions
    "destination", "target_url", "target", "deep_link", "deeplink",
    "redirect_url", "redirect", "url", "link", "href",
    // AppsFlyer OneLink
    "af_dp", "af_web_dp", "af_deep_link", "af_web_deep_link",
    // Firebase / GCM
    "gcm.notification.link", "notification_link",
  ]

  private static func destination(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidateKeys {
        guard let raw = dictionary[candidate] as? String else { continue }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
          return trimmed
        }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }

    for container in ["payload", "data", "gcm.notification", "aps"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
