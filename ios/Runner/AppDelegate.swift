import UIKit
import Flutter
import MapboxMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    MapboxOptions.accessToken = "pk.eyJ1IjoiaGFuYWp1bmdqdW4iLCJhIjoiY21qaTZ0amNwMDF2MzNnb3l6Mjhwd2doNyJ9.kvF6H1ock64cYC3voff9tQ"

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
