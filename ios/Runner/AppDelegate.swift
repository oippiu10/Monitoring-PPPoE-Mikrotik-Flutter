import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Registrasi otomatis tanpa harus import modul di atas
    if let workmanagerPlugin = self.registrar(forPlugin: "WorkmanagerPlugin") {
       // Workmanager registrasi otomatis melalui GeneratedPluginRegistrant
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
