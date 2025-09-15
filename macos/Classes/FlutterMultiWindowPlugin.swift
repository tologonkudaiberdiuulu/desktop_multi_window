import Cocoa
import FlutterMacOS

public class FlutterMultiWindowPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  static func registerInternal(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "mixin.one/flutter_multi_window", binaryMessenger: registrar.messenger)
    let instance = FlutterMultiWindowPlugin()
    let events = FlutterEventChannel(name: "desktop_multi_window/events",
                                     binaryMessenger: registrar.messenger)
    events.setStreamHandler(instance)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    registerInternal(with: registrar)
    guard let app = NSApplication.shared.delegate as? FlutterAppDelegate else {
      debugPrint("failed to find flutter main window, application delegate is not FlutterAppDelegate")
      return
    }
    guard let window = app.mainFlutterWindow else {
      debugPrint("failed to find flutter main window")
      return
    }
    let mainWindowChannel = WindowChannel.register(with: registrar, windowId: 0)
    MultiWindowManager.shared.attachMainWindow(window: window, mainWindowChannel)
  }

  // MARK: FlutterStreamHandler
  public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = eventSink
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  // Helper to emit
  func sendEvent(_ map: [String: Any]) {
    eventSink?(map)
  }

  // Expose a shared reference or pass `instance` to windows as needed
  static var shared: FlutterMultiWindowPlugin?
  override init() {
    super.init()
    FlutterMultiWindowPlugin.shared = self
  }

  public typealias OnWindowCreatedCallback = (FlutterViewController) -> Void
  static var onWindowCreatedCallback: OnWindowCreatedCallback?

  public static func setOnWindowCreatedCallback(_ callback: @escaping OnWindowCreatedCallback) {
    onWindowCreatedCallback = callback
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createWindow":
      let arguments = call.arguments as? String
      let windowId = MultiWindowManager.shared.create(arguments: arguments ?? "")
      result(windowId)
    case "show":
      let windowId = call.arguments as! Int64
      MultiWindowManager.shared.show(windowId: windowId)
      result(nil)
    case "hide":
      let windowId = call.arguments as! Int64
      MultiWindowManager.shared.hide(windowId: windowId)
      result(nil)
    case "close":
      let windowId = call.arguments as! Int64
      MultiWindowManager.shared.close(windowId: windowId)
      result(nil)
    case "center":
      let windowId = call.arguments as! Int64
      MultiWindowManager.shared.center(windowId: windowId)
      result(nil)
    case "setFrame":
      let arguments = call.arguments as! [String: Any?]
      let windowId = arguments["windowId"] as! Int64
      let left = arguments["left"] as! Double
      let top = arguments["top"] as! Double
      let width = arguments["width"] as! Double
      let height = arguments["height"] as! Double
      let rect = NSRect(x: left, y: top, width: width, height: height)
      MultiWindowManager.shared.setFrame(windowId: windowId, frame: rect)
      result(nil)
    case "setTitle":
      let arguments = call.arguments as! [String: Any?]
      let windowId = arguments["windowId"] as! Int64
      let title = arguments["title"] as! String
      MultiWindowManager.shared.setTitle(windowId: windowId, title: title)
      result(nil)
	case "resizable":
	  let arguments = call.arguments as! [String: Any?]
	  let windowId = arguments["windowId"] as! Int64
	  let resizable = arguments["resizable"] as! Bool
	  MultiWindowManager.shared.resizable(windowId: windowId, resizable: resizable)
	  result(nil)
    case "setFrameAutosaveName":
      let arguments = call.arguments as! [String: Any?]
      let windowId = arguments["windowId"] as! Int64
      let frameAutosaveName = arguments["name"] as! String
      MultiWindowManager.shared.setFrameAutosaveName(windowId: windowId, name: frameAutosaveName)
      result(nil)
    case "getAllSubWindowIds":
      let subWindowIds = MultiWindowManager.shared.getAllSubWindowIds()
      result(subWindowIds)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
