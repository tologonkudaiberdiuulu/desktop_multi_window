//
//  FlutterWindow.swift
//  flutter_multi_window
//
//  Created by Bin Yang on 2022/1/10.
//
import Cocoa
import FlutterMacOS
import Foundation

class BaseFlutterWindow: NSObject {
  private let window: NSWindow
  let windowChannel: WindowChannel

  init(window: NSWindow, channel: WindowChannel) {
    self.window = window
    self.windowChannel = channel
    super.init()
  }

  func show() {
    if Thread.isMainThread {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    } else {
      DispatchQueue.main.async {
        self.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
  }

  func hide() {
    if Thread.isMainThread {
      window.orderOut(nil)
    } else {
      DispatchQueue.main.async {
        self.window.orderOut(nil)
      }
    }
  }

  func center() {
    if Thread.isMainThread {
      window.center()
    } else {
      DispatchQueue.main.async {
        self.window.center()
      }
    }
  }

  func setFrame(frame: NSRect) {
    if Thread.isMainThread {
      window.setFrame(frame, display: false, animate: true)
    } else {
      DispatchQueue.main.async {
        self.window.setFrame(frame, display: false, animate: true)
      }
    }
  }

  func setTitle(title: String) {
    if Thread.isMainThread {
      window.title = title
    } else {
      DispatchQueue.main.async {
        self.window.title = title
      }
    }
  }

  func resizable(resizable: Bool) {
    let apply: () -> Void = {
      if (resizable) {
        self.window.styleMask.insert(.resizable)
      } else {
        self.window.styleMask.remove(.resizable)
      }
    }
    if Thread.isMainThread {
      apply()
    } else {
      DispatchQueue.main.async { apply() }
    }
  }

  func close() {
    if Thread.isMainThread {
      window.close()
    } else {
      DispatchQueue.main.async {
        self.window.close()
      }
    }
  }

  func setFrameAutosaveName(name: String) {
    if Thread.isMainThread {
      window.setFrameAutosaveName(name)
    } else {
      DispatchQueue.main.async {
        self.window.setFrameAutosaveName(name)
      }
    }
  }
}

class FlutterWindow: BaseFlutterWindow {
  let windowId: Int64

  let window: NSWindow

  weak var delegate: WindowManagerDelegate?

  init(id: Int64, arguments: String) {
    windowId = id
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
      styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView],
      backing: .buffered, defer: false)
    let project = FlutterDartProject()
    project.dartEntrypointArguments = ["multi_window", "\(windowId)", arguments]
    let flutterViewController = FlutterViewController(project: project)
    window.contentViewController = flutterViewController

    let plugin = flutterViewController.registrar(forPlugin: "FlutterMultiWindowPlugin")
    FlutterMultiWindowPlugin.registerInternal(with: plugin)
    let windowChannel = WindowChannel.register(with: plugin, windowId: id)
    // Give app a chance to register plugin.
    FlutterMultiWindowPlugin.onWindowCreatedCallback?(flutterViewController)

    super.init(window: window, channel: windowChannel)

    window.delegate = self
    window.isReleasedWhenClosed = false
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didChangeOcclusionState),
      name: NSApplication.willBecomeActiveNotification,
      object: nil
    )
        
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didChangeOcclusionState),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )
  }

  deinit {
    debugPrint("release window resource")
    window.delegate = nil
    NotificationCenter.default.removeObserver(self)
    if let flutterViewController = window.contentViewController as? FlutterViewController {
      flutterViewController.engine.shutDownEngine()
    }
    window.contentViewController = nil
    window.windowController = nil
  }

  @objc func didChangeOcclusionState(_ notification: Notification) {
    if let controller = window.contentViewController as? FlutterViewController {
      controller.engine.handleDidChangeOcclusionState(notification)
    }
  }
}

extension FlutterWindow: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    debugPrint("windowWillClose called for windowId: \(windowId)")
    delegate?.onClose(windowId: windowId)
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    debugPrint("windowShouldClose called for windowId: \(windowId) isVisible=\(sender.isVisible)")

    // Inform manager about close request on main thread and schedule a fallback
    let performCloseNotify: () -> Void = {
      self.delegate?.onClose(windowId: self.windowId)

      // If the window remains visible after a short delay, force close it.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        if sender.isVisible {
          debugPrint("window \(self.windowId) still visible after close request — forcing close")
          sender.close()
        }
      }
    }

    if Thread.isMainThread {
      performCloseNotify()
    } else {
      DispatchQueue.main.async { performCloseNotify() }
    }

    return true
  }
}
