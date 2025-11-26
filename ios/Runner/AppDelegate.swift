import Flutter
import UIKit
import Security

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
  // Register MethodChannel for biometric helper methods (deleteLocalKey)
  let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
  let channel = FlutterMethodChannel(name: "com.example.frontend/biometric", binaryMessenger: controller.binaryMessenger)
  channel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
    switch call.method {
    case "deleteLocalKey":
      // Attempt to remove SecKey(s) with application tag "biometric_key_default"
      let tag = "biometric_key_default"
      if let tagData = tag.data(using: .utf8) {
        let query: [String: Any] = [
          kSecClass as String: kSecClassKey,
          kSecAttrApplicationTag as String: tagData
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
          result(true)
        } else {
          result(false)
        }
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  })
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
