import AVFoundation
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let mediaPickerHandler = MediaPickerHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: MediaPickerHandler.channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.mediaPickerHandler.handle(call, result: result)
    }
  }
}

// MARK: - MediaPickerHandler
// Embedded in AppDelegate.swift on purpose: this file is already part of the
// Runner target, so no "Add Files to Runner" step in Xcode is needed.

/// Native side of the "custom_media_picker" MethodChannel (iOS).
///
/// Methods:
///  - checkPermission              -> "granted" | "limited" | "notDetermined" | "denied"
///  - requestPermission            -> "granted" | "limited" | "denied"
///  - openAppSettings              -> Bool
///  - getAssets(type, page, size, albumId?) -> [[String: Any]]
///  - getAlbums(type)              -> [[String: Any]] (collections)
///  - getThumbnail(id, type, size) -> FlutterStandardTypedData (JPEG)
///  - getOriginalPath(id, type)    -> String absolute path
class MediaPickerHandler: NSObject {

    static let channelName = "custom_media_picker"

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermission":
            result(currentStatus())

        case "requestPermission":
            requestPermission(result)

        case "openAppSettings":
            openAppSettings(result)

        case "getAssets":
            let args = call.arguments as? [String: Any] ?? [:]
            let type = args["type"] as? String ?? "all"
            let page = args["page"] as? Int ?? 0
            let pageSize = args["pageSize"] as? Int ?? 60
            let albumId = args["albumId"] as? String
            DispatchQueue.global(qos: .userInitiated).async {
                let assets = self.queryAssets(
                    type: type, page: page, pageSize: pageSize, albumId: albumId)
                DispatchQueue.main.async { result(assets) }
            }

        case "getAlbums":
            let args = call.arguments as? [String: Any] ?? [:]
            let type = args["type"] as? String ?? "all"
            DispatchQueue.global(qos: .userInitiated).async {
                let albums = self.queryAlbums(type: type)
                DispatchQueue.main.async { result(albums) }
            }

        case "getThumbnail":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "id is required", details: nil))
                return
            }
            let size = args["size"] as? Int ?? 256
            getThumbnail(id: id, size: size, result: result)

        case "getOriginalPath":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "id is required", details: nil))
                return
            }
            getOriginalPath(id: id, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission

    /// Current status without showing anything. `notDetermined` is reported
    /// separately from `denied` because iOS only ever presents the system
    /// dialog once: after a refusal `requestAuthorization` returns the stored
    /// answer immediately and the user has to be sent to Settings instead.
    private func currentStatus() -> String {
        if #available(iOS 14, *) {
            switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
            case .authorized: return "granted"
            case .limited: return "limited"
            case .notDetermined: return "notDetermined"
            default: return "denied"
            }
        } else {
            switch PHPhotoLibrary.authorizationStatus() {
            case .authorized: return "granted"
            case .notDetermined: return "notDetermined"
            default: return "denied"
            }
        }
    }

    private func requestPermission(_ result: @escaping FlutterResult) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized: result("granted")
                    case .limited: result("limited")
                    default: result("denied")
                    }
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    result(status == .authorized ? "granted" : "denied")
                }
            }
        }
    }

    private func openAppSettings(_ result: @escaping FlutterResult) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            result(false)
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { opened in
                result(opened)
            }
        }
    }

    // MARK: - Query

    private func fetchOptions(for type: String) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        switch type {
        case "image":
            options.predicate = NSPredicate(
                format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case "video":
            options.predicate = NSPredicate(
                format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        default:
            options.predicate = NSPredicate(
                format: "mediaType = %d OR mediaType = %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue)
        }
        return options
    }

    private func queryAssets(
        type: String, page: Int, pageSize: Int, albumId: String? = nil
    ) -> [[String: Any]] {
        let fetch: PHFetchResult<PHAsset>
        if let albumId = albumId,
           let collection = PHAssetCollection.fetchAssetCollections(
               withLocalIdentifiers: [albumId], options: nil).firstObject {
            fetch = PHAsset.fetchAssets(in: collection, options: fetchOptions(for: type))
        } else {
            fetch = PHAsset.fetchAssets(with: fetchOptions(for: type))
        }
        let start = page * pageSize
        guard start < fetch.count else { return [] }
        let end = min(start + pageSize, fetch.count)

        var list: [[String: Any]] = []
        fetch.enumerateObjects(at: IndexSet(integersIn: start..<end), options: []) {
            asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            list.append([
                "id": asset.localIdentifier,
                "type": asset.mediaType == .video ? "video" : "image",
                "durationMs": Int(asset.duration * 1000),
                "width": asset.pixelWidth,
                "height": asset.pixelHeight,
                "dateAdded": Int(asset.creationDate?.timeIntervalSince1970 ?? 0),
                "name": resources.first?.originalFilename as Any,
                "sizeBytes": NSNull(),
            ])
        }
        return list
    }

    // MARK: - Albums

    /// User albums + useful smart albums (Favorites, Screenshots, Videos,
    /// Selfies, ...). Skips the "Recents" smart album — that's the picker's
    /// own Recent tab — and any album with no asset matching the filter.
    private func queryAlbums(type: String) -> [[String: Any]] {
        var list: [[String: Any]] = []

        func append(_ collections: PHFetchResult<PHAssetCollection>) {
            collections.enumerateObjects { collection, _, _ in
                if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                    return // = our "Recent" tab
                }
                let assets = PHAsset.fetchAssets(
                    in: collection, options: self.fetchOptions(for: type))
                guard assets.count > 0, let cover = assets.firstObject else {
                    return
                }
                list.append([
                    "id": collection.localIdentifier,
                    "name": collection.localizedTitle ?? "",
                    "count": assets.count,
                    "coverId": cover.localIdentifier,
                    "coverType": cover.mediaType == .video ? "video" : "image",
                ])
            }
        }

        append(PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil))
        append(PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .any, options: nil))

        // Biggest albums first — matches what users expect to see on top.
        return list.sorted {
            ($0["count"] as? Int ?? 0) > ($1["count"] as? Int ?? 0)
        }
    }

    // MARK: - Thumbnail

    private func getThumbnail(id: String, size: Int, result: @escaping FlutterResult) {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [id], options: nil).firstObject
        else {
            result(nil)
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat // single callback
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let scale = UIScreen.main.scale
        let target = CGSize(
            width: CGFloat(size) * scale / 2,
            height: CGFloat(size) * scale / 2)

        var replied = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                guard !replied else { return }
                replied = true
                if let data = image?.jpegData(compressionQuality: 0.8) {
                    result(FlutterStandardTypedData(bytes: data))
                } else {
                    result(nil)
                }
            }
        }
    }

    // MARK: - Original path

    private func getOriginalPath(id: String, result: @escaping FlutterResult) {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [id], options: nil).firstObject
        else {
            result(nil)
            return
        }

        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true // download from iCloud if needed
            options.version = .current
            PHImageManager.default().requestAVAsset(
                forVideo: asset, options: options
            ) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    DispatchQueue.main.async { result(urlAsset.url.path) }
                } else {
                    // Slow-mo videos come back as AVComposition — copy instead.
                    self.copyResourceToTmp(asset: asset, result: result)
                }
            }
        } else {
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true
            asset.requestContentEditingInput(with: options) { input, _ in
                if let url = input?.fullSizeImageURL {
                    DispatchQueue.main.async { result(url.path) }
                } else {
                    self.copyResourceToTmp(asset: asset, result: result)
                }
            }
        }
    }

    private func copyResourceToTmp(asset: PHAsset, result: @escaping FlutterResult) {
        let resources = PHAssetResource.assetResources(for: asset)
        // Prefer the full-size original resource.
        let preferred = resources.first {
            $0.type == .photo || $0.type == .video
        } ?? resources.first
        guard let resource = preferred else {
            DispatchQueue.main.async { result(nil) }
            return
        }
        let safeId = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
        let fileName = "picker_\(safeId)_\(resource.originalFilename)"
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: url.path) {
            DispatchQueue.main.async { result(url.path) }
            return
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(
            for: resource, toFile: url, options: options
        ) { error in
            DispatchQueue.main.async {
                result(error == nil ? url.path : nil)
            }
        }
    }
}
