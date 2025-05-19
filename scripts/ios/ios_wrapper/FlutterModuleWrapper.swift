import UIKit
import Flutter

public class FlutterModuleWrapper {
    public static let shared = FlutterModuleWrapper()
    
    private let engine: FlutterEngine
    private var methodChannel: FlutterMethodChannel?
    private var pendingMessages: [String] = []
    
    private init() {
        engine = FlutterEngine(name: "flutter_module_engine")
        engine.run()
        
        // Set up method channel
        let binaryMessenger = engine.binaryMessenger
        methodChannel = FlutterMethodChannel(name: "com.example.flutter_wrapper/platform_channel",
                                            binaryMessenger: binaryMessenger)
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "Wrapper is no longer available", details: nil))
                return
            }
            
            switch call.method {
            case "messageFromFlutter":
                if let args = call.arguments as? [String: Any],
                   let message = args["message"] as? String {
                    print("Message from Flutter: \(message)")
                    // Process the message here if needed
                    result("iOS received: \(message)")
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }
                
            case "getBatteryLevel":
                let batteryLevel = self.getBatteryLevel()
                if batteryLevel >= 0 {
                    result(batteryLevel)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "Battery level not available", details: nil))
                }
                
            case "sendMessage":
                if let args = call.arguments as? [String: Any],
                   let message = args["message"] as? String {
                    // Process the message from Flutter
                    let response = "iOS processed: \(message)"
                    print(response)
                    result(response)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    public func openFlutterModule(from viewController: UIViewController, message: String? = nil) {
        // Create the FlutterViewController
        let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        
        // Send initial message if needed
        if let message = message {
            sendMessageToFlutter(message)
        }
        
        // Present the Flutter view controller
        viewController.present(flutterViewController, animated: true, completion: nil)
    }
    
    public func sendMessageToFlutter(_ message: String) {
        methodChannel?.invokeMethod("messageFromNative", arguments: ["message": message])
    }
    
    // Sends a structured message to Flutter
    public func sendMessage(message: String, data: [String: Any]? = nil) {
        var arguments: [String: Any] = ["message": message]
        
        // Add additional data if provided
        if let data = data {
            for (key, value) in data {
                arguments[key] = value
            }
        }
        
        methodChannel?.invokeMethod("messageFromNative", arguments: arguments)
    }
    
    // Get the device's battery level
    private func getBatteryLevel() -> Int {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        if UIDevice.current.batteryState == .unknown {
            return -1
        } else {
            return Int(UIDevice.current.batteryLevel * 100)
        }
    }
    
    // Get the battery level and return it directly - can be called from Swift
    public func getBatteryLevelValue() -> Int {
        return getBatteryLevel()
    }
}
