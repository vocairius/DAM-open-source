import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(
      name: "vault_dam/macOS",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "applicationSupportDirectory":
        guard let directory = FileManager.default.urls(
          for: .applicationSupportDirectory,
          in: .userDomainMask
        ).first?.appendingPathComponent("Vault DAM", isDirectory: true) else {
          result(FlutterError(
            code: "support_directory_unavailable",
            message: "Could not resolve the application support directory.",
            details: nil
          ))
          return
        }
        do {
          try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
          )
          result(directory.path)
        } catch {
          result(FlutterError(
            code: "support_directory_unavailable",
            message: error.localizedDescription,
            details: nil
          ))
        }
      case "revealInFinder":
        guard let path = call.arguments as? String else {
          result(FlutterError(
            code: "invalid_path",
            message: "A file path is required.",
            details: nil
          ))
          return
        }
        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        guard NSWorkspace.shared.selectFile(
          path,
          inFileViewerRootedAtPath: parentPath
        ) else {
          result(FlutterError(
            code: "finder_failed",
            message: "The file may have moved or Finder could not reveal it.",
            details: path
          ))
          return
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
