import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  /// Files opened with ZON (Finder "Open With", double-clicking a .torrent)
  /// before Dart was ready to receive them.
  private var pendingFiles: [String] = []
  private var channel: FlutterMethodChannel?
  private var dartReady = false

  // ZON keeps downloading from the tray when its window is closed; quitting
  // goes through the tray menu or the window when tray mode is off.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // magnet: links arrive as GetURL Apple events, handled by app_links.
  // Documents arrive here.
  override func application(_ application: NSApplication, open urls: [URL]) {
    let files = urls.filter { $0.isFileURL }.map { $0.path }
    guard !files.isEmpty else { return }
    if dartReady, let channel = channel {
      channel.invokeMethod("open", arguments: files)
    } else {
      pendingFiles.append(contentsOf: files)
    }
  }

  func attach(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "zon/open_files",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // Dart is listening: hand over everything queued so far.
      self.dartReady = true
      result(self.pendingFiles)
      self.pendingFiles.removeAll()
    }
    self.channel = channel

    let notify = FlutterMethodChannel(
      name: "zon/notify",
      binaryMessenger: controller.engine.binaryMessenger)
    notify.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show",
        let args = call.arguments as? [String: String]
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.showNotification(title: args["title"] ?? "ZON", body: args["body"] ?? "")
      result(nil)
    }
    notifyChannel = notify
  }

  private var notifyChannel: FlutterMethodChannel?

  private func showNotification(title: String, body: String) {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    // Asks once; later calls return the stored answer immediately.
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { return }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      center.add(
        UNNotificationRequest(
          identifier: UUID().uuidString, content: content, trigger: nil))
    }
  }

  // While ZON is in front its own toast already says the same thing.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler(NSApp.isActive ? [] : [.banner, .sound])
  }

  // Clicking a notification brings ZON forward.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.first?.makeKeyAndOrderFront(nil)
    completionHandler()
  }
}
