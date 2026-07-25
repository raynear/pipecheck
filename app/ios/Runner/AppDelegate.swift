import Flutter
import UIKit

// Awesome Notification
import awesome_notifications
// Awesome Notification

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Awesome Notifications
    // This function registers the desired plugins to be used within a notification background action
    SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
        SwiftAwesomeNotificationsPlugin.register(
          with: registry.registrar(forPlugin: "io.flutter.plugins.awesomenotifications.AwesomeNotificationsPlugin")!)
    }
    // Awesome Notifications

    // (workmanager / GoogleMaps 등록 잔재는 P1-17b에서 제거 —
    //  pubspec에서 주석 처리된 의존이라 import가 iOS 빌드를 깨뜨렸음.
    //  해당 패키지를 켜는 포크는 examples/ 안내에 따라 재배선할 것)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
