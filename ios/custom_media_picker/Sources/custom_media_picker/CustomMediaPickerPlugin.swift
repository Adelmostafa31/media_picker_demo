import AVFoundation
import Flutter
import Photos
import UIKit
import UniformTypeIdentifiers

/// Native side of the "custom_media_picker" channels (iOS).
///
/// Methods:
///  - checkPermission   -> "granted" | "limited" | "notDetermined" | "permanentlyDenied"
///  - requestPermission -> same set, after the system dialog (shown only once by iOS)
///  - openAppSettings   -> Bool
///  - getAssets(type, page, pageSize, albumId?, ascending?, startDate?, endDate?, includeNames?)
///  - getAlbums(type)
///  - getThumbnail(id, type, size) -> FlutterStandardTypedData (JPEG) | nil
///  - getOriginalPath(id, type)    -> String | nil (always a private copy in tmp)
///  - clearCache
///
/// Event channel "custom_media_picker/gallery_changes" emits on library changes.
public class CustomMediaPickerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
    PHPhotoLibraryChangeObserver
{
    private static let channelName = "custom_media_picker"
    private static let changesChannelName = "custom_media_picker/gallery_changes"
    private static let cacheMaxAge: TimeInterval = 24 * 60 * 60

    private var eventSink: FlutterEventSink?
    private var observing = false
    private var pendingChange: DispatchWorkItem?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CustomMediaPickerPlugin()
        let channel = FlutterMethodChannel(
            name: channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        FlutterEventChannel(
            name: changesChannelName, binaryMessenger: registrar.messenger()
        ).setStreamHandler(instance)
        DispatchQueue.global(qos: .utility).async { instance.purgeStaleCache() }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "checkPermission":
            result(currentStatus())

        case "requestPermission":
            requestPermission(result)

        case "openAppSettings":
            openAppSettings(result)

        case "getAssets":
            let type = args["type"] as? String ?? "all"
            let page = (args["page"] as? NSNumber)?.intValue ?? 0
            let pageSize = (args["pageSize"] as? NSNumber)?.intValue ?? 60
            let albumId = args["albumId"] as? String
            let ascending = args["ascending"] as? Bool ?? false
            let startDate = (args["startDate"] as? NSNumber)?.intValue
            let endDate = (args["endDate"] as? NSNumber)?.intValue
            let includeNames = args["includeNames"] as? Bool ?? true
            DispatchQueue.global(qos: .userInitiated).async {
                let assets = self.queryAssets(
                    type: type, page: page, pageSize: pageSize, albumId: albumId,
                    ascending: ascending, startDate: startDate, endDate: endDate,
                    includeNames: includeNames)
                DispatchQueue.main.async { result(assets) }
            }

        case "getAlbums":
            let type = args["type"] as? String ?? "all"
            DispatchQueue.global(qos: .userInitiated).async {
                let albums = self.queryAlbums(type: type)
                DispatchQueue.main.async { result(albums) }
            }

        case "getThumbnail":
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "id is required", details: nil))
                return
            }
            let size = (args["size"] as? NSNumber)?.intValue ?? 256
            getThumbnail(id: id, size: size, result: result)

        case "getOriginalPath":
            guard let id = args["id"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "id is required", details: nil))
                return
            }
            getOriginalPath(id: id, result: result)

        case "saveToGallery":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let path = args["path"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "path is required", details: nil))
                return
            }
            saveToGallery(
                path: path, isVideo: (args["type"] as? String) == "video",
                album: args["album"] as? String, result: result)

        case "clearCache":
            DispatchQueue.global(qos: .utility).async {
                try? FileManager.default.removeItem(at: Self.cacheDir())
                DispatchQueue.main.async { result(nil) }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission

    /// iOS presents the system dialog only once, so every refusal (and
    /// parental `restricted`) is reported as `permanentlyDenied`: only
    /// Settings can change it.
    private static func map(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "granted"
        case .limited: return "limited"
        case .notDetermined: return "notDetermined"
        default: return "permanentlyDenied"
        }
    }

    private func currentStatus() -> String {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func requestPermission(_ result: @escaping FlutterResult) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async { result(Self.map(status)) }
        }
    }

    private func openAppSettings(_ result: @escaping FlutterResult) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            result(false)
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
        }
    }

    private var hasAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    // MARK: - Query

    /// `startDate`/`endDate` are unix seconds (inclusive) on `creationDate`.
    private func fetchOptions(
        for type: String, ascending: Bool = false, startDate: Int? = nil, endDate: Int? = nil
    ) -> PHFetchOptions {
        let options = PHFetchOptions()
        // localIdentifier is not sortable, so items sharing a creationDate keep
        // PhotoKit's stable fetch order; the Dart side also de-duplicates by id.
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
        var predicates: [NSPredicate] = []
        switch type {
        case "image":
            predicates.append(
                NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue))
        case "video":
            predicates.append(
                NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue))
        default:
            predicates.append(
                NSPredicate(
                    format: "mediaType = %d OR mediaType = %d",
                    PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue))
        }
        if let startSec = startDate, let endSec = endDate {
            predicates.append(
                NSPredicate(
                    format: "creationDate >= %@ AND creationDate <= %@",
                    Date(timeIntervalSince1970: TimeInterval(startSec)) as NSDate,
                    Date(timeIntervalSince1970: TimeInterval(endSec) + 0.999) as NSDate))
        }
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return options
    }

    private func queryAssets(
        type: String, page: Int, pageSize: Int, albumId: String?,
        ascending: Bool, startDate: Int?, endDate: Int?, includeNames: Bool
    ) -> [[String: Any]] {
        let options = fetchOptions(
            for: type, ascending: ascending, startDate: startDate, endDate: endDate)
        let fetch: PHFetchResult<PHAsset>
        if let albumId = albumId {
            // A deleted album must not silently fall back to the whole library.
            guard
                let collection = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [albumId], options: nil
                ).firstObject
            else { return [] }
            fetch = PHAsset.fetchAssets(in: collection, options: options)
        } else {
            fetch = PHAsset.fetchAssets(with: options)
        }
        let start = page * pageSize
        guard start < fetch.count else { return [] }
        let end = min(start + pageSize, fetch.count)

        var list: [[String: Any]] = []
        fetch.enumerateObjects(at: IndexSet(integersIn: start..<end), options: []) { asset, _, _ in
            let created = Int(asset.creationDate?.timeIntervalSince1970 ?? 0)
            // Looking up resources per asset is slow; only the list layout
            // shows file names.
            let name: Any =
                includeNames
                ? (PHAssetResource.assetResources(for: asset).first?.originalFilename as Any)
                : NSNull()
            list.append([
                "id": asset.localIdentifier,
                "type": asset.mediaType == .video ? "video" : "image",
                "durationMs": Int(asset.duration * 1000),
                "width": asset.pixelWidth,
                "height": asset.pixelHeight,
                "dateAdded": created,
                "dateTaken": created,
                "name": name,
                "sizeBytes": NSNull(),
            ])
        }
        return list
    }

    // MARK: - Albums

    /// Subtypes never listed: the library itself (the picker's own Recent
    /// tab) and the Hidden album, which Photos locks behind Face ID.
    private static let skippedSubtypes: Set<PHAssetCollectionSubtype> = [
        .smartAlbumUserLibrary, .smartAlbumAllHidden,
    ]

    private func queryAlbums(type: String) -> [[String: Any]] {
        var entries: [(date: Date, album: [String: Any])] = []

        func append(_ collections: PHFetchResult<PHAssetCollection>) {
            collections.enumerateObjects { collection, _, _ in
                if Self.skippedSubtypes.contains(collection.assetCollectionSubtype) { return }
                let assets = PHAsset.fetchAssets(in: collection, options: self.fetchOptions(for: type))
                guard let cover = assets.firstObject else { return }
                entries.append(
                    (
                        cover.creationDate ?? .distantPast,
                        [
                            "id": collection.localIdentifier,
                            "name": collection.localizedTitle as Any,
                            "count": assets.count,
                            "coverId": cover.localIdentifier,
                            "coverType": cover.mediaType == .video ? "video" : "image",
                        ]
                    ))
            }
        }

        append(PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil))
        append(
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil))

        // Newest cover first, matching Android.
        return entries.sorted { $0.date > $1.date }.map { $0.album }
    }

    // MARK: - Thumbnail

    private func getThumbnail(id: String, size: Int, result: @escaping FlutterResult) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else {
            result(nil)
            return
        }
        let options = PHImageRequestOptions()
        // Opportunistic + no network: grid thumbnails never download iCloud
        // originals. A degraded image is kept as the fallback when the
        // high-quality one is only available in the cloud.
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        let target = CGSize(width: size, height: size)
        var fallback: UIImage?
        var replied = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: target, contentMode: .aspectFill, options: options
        ) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            DispatchQueue.main.async {
                if replied { return }
                if degraded {
                    fallback = image ?? fallback
                    return
                }
                replied = true
                let best = image ?? fallback
                if let data = best?.jpegData(compressionQuality: 0.8) {
                    result(FlutterStandardTypedData(bytes: data))
                } else {
                    result(nil)
                }
            }
        }
    }

    // MARK: - Original path

    private static func cacheDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            "custom_media_picker", isDirectory: true)
    }

    private func purgeStaleCache() {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Self.cacheMaxAge)
        guard
            let files = try? fm.contentsOfDirectory(
                at: Self.cacheDir(), includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified = modified, modified < cutoff { try? fm.removeItem(at: file) }
        }
    }

    /// The copy's name includes the asset's modification date, so an edited
    /// photo never reuses a stale copy.
    private func cacheURL(for asset: PHAsset, ext: String) -> URL {
        let safeId = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
        let version = Int(asset.modificationDate?.timeIntervalSince1970 ?? 0)
        return Self.cacheDir().appendingPathComponent("picker_\(safeId)_\(version).\(ext)")
    }

    /// Paths inside the Photos library are readable only while PhotoKit's
    /// sandbox extension lives, so every original is copied into our own
    /// tmp folder first. Writes go to a `.part` file and are moved into place,
    /// so an interrupted copy is never served later.
    private func getOriginalPath(id: String, result: @escaping FlutterResult) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else {
            result(nil)
            return
        }
        let reply: (String?) -> Void = { path in DispatchQueue.main.async { result(path) } }
        try? FileManager.default.createDirectory(
            at: Self.cacheDir(), withIntermediateDirectories: true)

        if asset.mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) {
                avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    let dest = self.cacheURL(for: asset, ext: urlAsset.url.pathExtension)
                    reply(self.place(at: dest) { part in
                        try FileManager.default.copyItem(at: urlAsset.url, to: part)
                    })
                } else {
                    // Slow-mo videos come back as AVComposition: copy the resource.
                    self.copyResource(of: asset, reply: reply)
                }
            }
        } else {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
                data, uti, _, _ in
                guard let data = data else {
                    self.copyResource(of: asset, reply: reply)
                    return
                }
                let ext = uti.flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg"
                let dest = self.cacheURL(for: asset, ext: ext)
                reply(self.place(at: dest) { part in try data.write(to: part) })
            }
        }
    }

    /// Writes via [write] to `dest.part`, then moves it to [dest].
    private func place(at dest: URL, write: (URL) throws -> Void) -> String? {
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) { return dest.path }
        let part = dest.appendingPathExtension("part")
        try? fm.removeItem(at: part)
        do {
            try write(part)
            try fm.moveItem(at: part, to: dest)
            return dest.path
        } catch {
            try? fm.removeItem(at: part)
            return fm.fileExists(atPath: dest.path) ? dest.path : nil
        }
    }

    // MARK: - Save to gallery

    /// Adds a captured file to the library (optionally into [album], created
    /// on demand) and returns the new asset's localIdentifier. Needs only
    /// add-only access (NSPhotoLibraryAddUsageDescription), unless [album] is
    /// set: finding or creating an album needs read/write access.
    private func saveToGallery(
        path: String, isVideo: Bool, album: String?, result: @escaping FlutterResult
    ) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            result(FlutterError(code: "BAD_ARGS", message: "No file at \(path)", details: nil))
            return
        }
        let wantsAlbum = !(album ?? "").isEmpty
        let level: PHAccessLevel = wantsAlbum ? .readWrite : .addOnly
        PHPhotoLibrary.requestAuthorization(for: level) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PERMISSION", message: "Photo library add access denied",
                        details: nil))
                }
                return
            }
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let request = isVideo
                    ? PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    : PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                placeholder = request?.placeholderForCreatedAsset
                if wantsAlbum, let name = album, let asset = placeholder {
                    let existing = PHAssetCollection.fetchAssetCollections(
                        with: .album, subtype: .albumRegular, options: nil)
                    var target: PHAssetCollection?
                    existing.enumerateObjects { c, _, stop in
                        if c.localizedTitle == name { target = c; stop.pointee = true }
                    }
                    let albumRequest = target.flatMap { PHAssetCollectionChangeRequest(for: $0) }
                        ?? PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                            withTitle: name)
                    albumRequest.addAssets([asset] as NSArray)
                }
            }) { ok, error in
                DispatchQueue.main.async {
                    if ok, let id = placeholder?.localIdentifier {
                        result(id)
                    } else {
                        result(FlutterError(
                            code: "SAVE_ERROR",
                            message: error?.localizedDescription ?? "Save failed", details: nil))
                    }
                }
            }
        }
    }

    private func copyResource(of asset: PHAsset, reply: @escaping (String?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        let preferredTypes: [PHAssetResourceType] = [.fullSizePhoto, .fullSizeVideo, .photo, .video]
        let resource =
            preferredTypes.lazy.compactMap { type in resources.first { $0.type == type } }.first
            ?? resources.first
        guard let resource = resource else {
            reply(nil)
            return
        }
        let ext = (resource.originalFilename as NSString).pathExtension
        let dest = cacheURL(for: asset, ext: ext.isEmpty ? "dat" : ext)
        if FileManager.default.fileExists(atPath: dest.path) {
            reply(dest.path)
            return
        }
        let part = dest.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: part)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: resource, toFile: part, options: options) {
            error in
            reply(self.place(at: dest) { tmp in
                if let error = error { throw error }
                // writeData already produced `tmp`; place() only moves it.
                _ = tmp
            })
        }
    }

    // MARK: - Gallery changes

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        // Registering before access is granted could trigger the prompt.
        if !observing && hasAccess {
            PHPhotoLibrary.shared().register(self)
            observing = true
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if observing {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
            observing = false
        }
        pendingChange?.cancel()
        eventSink = nil
        return nil
    }

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.pendingChange?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.eventSink?(nil) }
            self.pendingChange = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }
}
