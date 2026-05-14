import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let downloadsChannelName = "nice_view/downloads"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: downloadsChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "saveImage" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.saveImage(call: call, result: result)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func saveImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let typedBytes = arguments["bytes"] as? FlutterStandardTypedData,
          let image = UIImage(data: typedBytes.data) else {
      result(
        FlutterError(
          code: "INVALID_IMAGE",
          message: "图片数据无效",
          details: nil
        )
      )
      return
    }

    requestPhotoAddAuthorization { allowed in
      guard allowed else {
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

      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result("photos://saved")
            return
          }

          result(
            FlutterError(
              code: "SAVE_IMAGE_FAILED",
              message: error?.localizedDescription ?? "保存到系统相册失败",
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
}
