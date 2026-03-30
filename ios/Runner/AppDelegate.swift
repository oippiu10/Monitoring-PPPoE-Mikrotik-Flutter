import UIKit
import Flutter
import workmanager // Wajib ditambahkan jika menggunakan plugin workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // --- TAMBAHKAN KODE INI ---
    // Registrasi Workmanager agar tidak crash saat running di background iOS
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }
    // --------------------------

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
