import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let downloadsChannelName = "nice_view/downloads"
  private var downloadsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerDownloadsChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerDownloadsChannel() {
    let messenger: FlutterBinaryMessenger
    if let registrar = registrar(forPlugin: "NiceViewDownloadsPlugin") {
      messenger = registrar.messenger()
    } else if let controller = window?.rootViewController as? FlutterViewController {
      messenger = controller.binaryMessenger
    } else {
      return
    }

    let channel = FlutterMethodChannel(
      name: downloadsChannelName,
      binaryMessenger: messenger
    )
    downloadsChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.saveImage(call: call, result: result)
    }
  }

  private func saveImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let typedBytes = arguments["bytes"] as? FlutterStandardTypedData,
          !typedBytes.data.isEmpty else {
      result(
        FlutterError(
          code: "INVALID_IMAGE",
          message: "图片数据无效",
          details: nil
        )
      )
      return
    }

    let fileName = sanitizedFileName(arguments["fileName"] as? String)
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    do {
      try typedBytes.data.write(to: tempURL, options: .atomic)
    } catch {
      result(
        FlutterError(
          code: "TEMP_FILE_FAILED",
          message: "临时图片文件写入失败",
          details: error.localizedDescription
        )
      )
      return
    }

    requestPhotoAddAuthorization { allowed in
      guard allowed else {
        try? FileManager.default.removeItem(at: tempURL)
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "PHOTO_PERMISSION_DENIED",
              message: "没有系统相册写入权限",
              details: nil
            )
          )
        }
        return
      }

      var createdChangeRequest = false
      PHPhotoLibrary.shared().performChanges({
        let request =
          PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
        createdChangeRequest = request != nil
      }) { success, error in
        try? FileManager.default.removeItem(at: tempURL)
        DispatchQueue.main.async {
          if success && createdChangeRequest {
            result("photos://saved")
            return
          }

          let message = createdChangeRequest
            ? (error?.localizedDescription ?? "保存到系统相册失败")
            : "图片格式暂时无法写入系统相册"
          result(
            FlutterError(
              code: createdChangeRequest ? "SAVE_IMAGE_FAILED" : "INVALID_IMAGE",
              message: message,
              details: nil
            )
          )
        }
      }
    }
  }

  private func requestPhotoAddAuthorization(_ completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        completion(status == .authorized || status == .limited)
      }
      return
    }

    PHPhotoLibrary.requestAuthorization { status in
      completion(status == .authorized)
    }
  }

  private func sanitizedFileName(_ fileName: String?) -> String {
    let fallback = "nice_view_\(UUID().uuidString).jpg"
    guard let fileName = fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
          !fileName.isEmpty else {
      return fallback
    }

    let lastPathComponent = URL(fileURLWithPath: fileName).lastPathComponent
    if lastPathComponent.isEmpty || lastPathComponent == "." || lastPathComponent == "/" {
      return fallback
    }
    return lastPathComponent
  }
}
