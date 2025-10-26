import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Brother Printer Plugin safely (commented out - plugin not found)
    // if let brotherRegistrar = registrar(forPlugin: "BrotherPrinterPlugin") {
    //   BrotherPrinterPlugin.register(with: brotherRegistrar)
    // }
    
    // Register MFi Authentication Plugin safely (commented out - plugin not found)
    // if let mfiRegistrar = registrar(forPlugin: "MFiAuthenticationPlugin") {
    //   MFiAuthenticationPlugin.register(with: mfiRegistrar)
    // }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
