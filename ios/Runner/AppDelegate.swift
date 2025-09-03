import UIKit
import Flutter
import TikTokBusinessSDK

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "tiktok_events", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "init":
        // Initialize TikTok SDK
        let config = TikTokConfig(accessToken: "TTdUMiO5Gc2FWhKaUBJCWGNhOpu7V1bd", appId: "6751144104", tiktokAppId: "7543926722593390609")
        TikTokBusiness.initializeSdk(config) { success, error in
          if (!success) { result(FlutterError(code: "tt_init_failed", message: error?.localizedDescription, details: nil)) }
          else { result(true) }
        }
      case "trackTrialStart":
        let event = TikTokBaseEvent(name: TTEventName.startTrial.rawValue)
        TikTokBusiness.trackTTEvent(event)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
