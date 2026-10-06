import AVFoundation
import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let adhanPreview = AdhanPreview()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications show prayer alerts while the app is open.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FadlNative") else {
      return
    }
    let adhan = FlutterMethodChannel(name: "fadl/adhan", binaryMessenger: registrar.messenger())
    adhan.setMethodCallHandler { [weak self] call, result in
      self?.adhanPreview.handle(call, result: result)
    }
    let widget = FlutterMethodChannel(
      name: "fadl/prayer_widget", binaryMessenger: registrar.messenger())
    widget.setMethodCallHandler(PrayerWidgetStore.handle)
  }
}

/// Plays the bundled 30-second adhan clips (the notification sounds) so the
/// user can hear a muezzin before choosing it. Scheduling stays in Dart.
final class AdhanPreview {
  private var player: AVAudioPlayer?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preview":
      let id = (call.arguments as? [String: Any])?["soundId"] as? String
      guard let id, let url = Bundle.main.url(forResource: id, withExtension: "caf") else {
        result(FlutterError(code: "missing_sound", message: nil, details: nil))
        return
      }
      do {
        player?.stop()
        player = try AVAudioPlayer(contentsOf: url)
        player?.play()
        result(nil)
      } catch {
        result(FlutterError(code: "preview_failed", message: nil, details: nil))
      }
    case "stopPreview":
      player?.stop()
      player = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Hands the offline prayer calendar to the home-screen widget through the
/// shared App Group (ios/PrayerWidget/PrayerWidget.swift reads it).
enum PrayerWidgetStore {
  static let appGroup = "group.com.fadl.fadl"
  static let scheduleKey = "fadl.prayer.schedule"

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: appGroup) else {
      result(FlutterError(code: "no_app_group", message: nil, details: nil))
      return
    }
    switch call.method {
    case "save":
      defaults.set(call.arguments as? String, forKey: scheduleKey)
    case "clear":
      defaults.removeObject(forKey: scheduleKey)
    default:
      result(FlutterMethodNotImplemented)
      return
    }
    WidgetCenter.shared.reloadAllTimelines()
    result(nil)
  }
}
