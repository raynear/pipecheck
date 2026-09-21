import Flutter
import UIKit

// Awesome Notification
import awesome_notifications
// Awesome Notification

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

  // UIScene 생명주기에서는 플러그인 등록이 여기로 온다 — didFinishLaunching 시점엔
  // 암시적 엔진도 window도 아직 없다(씬 채택 후 AppDelegate.window는 항상 nil).
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
