import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Required for push on iOS. Without this delegate assignment the system
    // never hands the APNs token to the messaging plugin, so getAPNSToken()
    // stays nil forever and FCM — which derives its token from the APNs one —
    // never issues a token. The Dart side polls for that token and gives up,
    // which is why iOS devices had no fcm_token stored server-side.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Kick off APNs registration. The permission prompt is still driven from
    // Dart (requestPermission); this only asks iOS for the device token.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
