package io.github.adelmostafa31.custom_media_picker

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.graphics.Bitmap
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Native side of the "custom_media_picker" channels (Android).
 *
 * Methods:
 *  - checkPermission  -> "granted" | "limited" | "notDetermined" | "denied" | "permanentlyDenied"
 *  - requestPermission -> same set, after the system dialog (if Android shows one)
 *  - openAppSettings  -> Boolean
 *  - getAssets(type, page, pageSize, albumId?, ascending?, startDate?, endDate?) -> List<Map>
 *  - getAlbums(type)  -> List<Map>
 *  - getThumbnail(id, type, size) -> ByteArray (JPEG) | null
 *  - getOriginalPath(id, type)    -> String | null
 *  - clearCache       -> null
 *
 * Event channel "custom_media_picker/gallery_changes" emits on MediaStore changes.
 */
class CustomMediaPickerPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    EventChannel.StreamHandler {

    companion object {
        private const val CHANNEL = "custom_media_picker"
        private const val CHANGES_CHANNEL = "custom_media_picker/gallery_changes"
        private const val PERMISSION_REQUEST_CODE = 4821
        private const val PREFS = "custom_media_picker"
        private const val PREF_ASKED = "permission_requested"
        private const val CACHE_DIR = "custom_media_picker"
        private const val CACHE_MAX_AGE_MS = 24L * 60 * 60 * 1000
        private const val CHANGE_DEBOUNCE_MS = 300L
    }

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var changesChannel: EventChannel? = null
    private var executor: ExecutorService? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity

    /** Every caller waiting on the one in-flight system permission dialog. */
    private val pendingPermissionResults = mutableListOf<MethodChannel.Result>()

    private var eventSink: EventChannel.EventSink? = null
    private var observer: ContentObserver? = null
    private val emitChange = Runnable { eventSink?.success(null) }

    // ------------------------------------------------------------ lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        executor = Executors.newFixedThreadPool(3)
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        changesChannel = EventChannel(binding.binaryMessenger, CHANGES_CHANNEL).also {
            it.setStreamHandler(this)
        }
        executor?.execute { purgeStaleCache() }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        changesChannel?.setStreamHandler(null)
        changesChannel = null
        onCancel(null)
        executor?.shutdown()
        executor = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        detachActivity()
        // The dialog's answer will never arrive (the recreated activity after
        // a config change does get it, so only a real detach lands here).
        // Answer waiting callers now, or Dart's shared request hangs forever.
        val waiting = pendingPermissionResults.toList()
        pendingPermissionResults.clear()
        if (waiting.isNotEmpty()) {
            val status = currentStatus()
            waiting.forEach { it.success(status) }
        }
    }

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    // ------------------------------------------------------------ dispatch

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> result.success(currentStatus())
            "requestPermission" -> requestPermission(result)
            "openAppSettings" -> openAppSettings(result)
            "getAssets" -> {
                val type = call.argument<String>("type") ?: "all"
                val page = call.argument<Number>("page")?.toInt() ?: 0
                val pageSize = call.argument<Number>("pageSize")?.toInt() ?: 60
                val albumId = call.argument<Any>("albumId")?.toString()
                val ascending = call.argument<Boolean>("ascending") ?: false
                val startDate = call.argument<Number>("startDate")?.toLong()
                val endDate = call.argument<Number>("endDate")?.toLong()
                runInBackground(result, "QUERY_ERROR") {
                    queryAssets(type, page, pageSize, albumId, ascending, startDate, endDate)
                }
            }
            "getAlbums" -> {
                val type = call.argument<String>("type") ?: "all"
                runInBackground(result, "QUERY_ERROR") { queryAlbums(type) }
            }
            "getThumbnail" -> {
                val id = call.argument<Any>("id")?.toString()?.toLongOrNull()
                    ?: return result.error("BAD_ARGS", "id is required", null)
                val type = call.argument<String>("type") ?: "image"
                val size = call.argument<Number>("size")?.toInt() ?: 256
                runInBackground(result, "THUMBNAIL_ERROR") { loadThumbnail(id, type, size) }
            }
            "getOriginalPath" -> {
                val id = call.argument<Any>("id")?.toString()?.toLongOrNull()
                    ?: return result.error("BAD_ARGS", "id is required", null)
                val type = call.argument<String>("type") ?: "image"
                runInBackground(result, "PATH_ERROR") { resolveOriginalPath(id, type) }
            }
            "clearCache" -> runInBackground(result, "CACHE_ERROR") {
                cacheDir().deleteRecursively()
                null
            }
            else -> result.notImplemented()
        }
    }

    /** Runs [work] off the main thread and replies on the main thread. */
    private fun runInBackground(
        result: MethodChannel.Result,
        errorCode: String,
        work: () -> Any?,
    ) {
        val pool = executor
        if (pool == null || pool.isShutdown) {
            result.error("DETACHED", "Plugin is detached from the engine", null)
            return
        }
        pool.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error(errorCode, e.message, null) }
            }
        }
    }

    // ------------------------------------------------------------ permission

    private fun requiredPermissions(): Array<String> = when {
        Build.VERSION.SDK_INT >= 34 -> arrayOf(
            Manifest.permission.READ_MEDIA_IMAGES,
            Manifest.permission.READ_MEDIA_VIDEO,
            Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
        )
        Build.VERSION.SDK_INT >= 33 -> arrayOf(
            Manifest.permission.READ_MEDIA_IMAGES,
            Manifest.permission.READ_MEDIA_VIDEO,
        )
        else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    private fun isGranted(permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun hasFullAccess(): Boolean {
        val perms = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        return perms.all(::isGranted)
    }

    /** Android 14+ "selected photos only", or one of images/videos on 13. */
    private fun hasPartialAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= 34 &&
            isGranted(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
        ) return true
        return Build.VERSION.SDK_INT >= 33 &&
            (isGranted(Manifest.permission.READ_MEDIA_IMAGES) ||
                isGranted(Manifest.permission.READ_MEDIA_VIDEO))
    }

    private val prefs get() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Android has no "not determined" API, so a stored flag tells a first run
     * apart from a refusal. After a refusal, a true rationale means the system
     * will still show the dialog once more ("denied"); a false one means it
     * won't, and only Settings helps ("permanentlyDenied").
     */
    private fun currentStatus(): String {
        if (hasFullAccess()) return "granted"
        if (hasPartialAccess()) return "limited"
        if (!prefs.getBoolean(PREF_ASKED, false)) return "notDetermined"
        val act = activity ?: return "denied"
        val canAskAgain = requiredPermissions().any {
            act.shouldShowRequestPermissionRationale(it)
        }
        return if (canAskAgain) "denied" else "permanentlyDenied"
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasFullAccess()) return result.success("granted")
        if (hasPartialAccess()) return result.success("limited")
        val act = activity ?: return result.error(
            "NO_ACTIVITY", "requestPermission needs a foreground activity", null,
        )
        pendingPermissionResults.add(result)
        // A dialog is already showing: this caller just waits for its answer.
        if (pendingPermissionResults.size > 1) return
        prefs.edit().putBoolean(PREF_ASKED, true).apply()
        act.requestPermissions(requiredPermissions(), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val status = currentStatus()
        val waiting = pendingPermissionResults.toList()
        pendingPermissionResults.clear()
        waiting.forEach { it.success(status) }
        return true
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            (activity ?: context).startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // ----------------------------------------------------------------- query

    private fun mediaTypeSelection(type: String): String {
        val col = MediaStore.Files.FileColumns.MEDIA_TYPE
        val image = MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE
        val video = MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
        return when (type) {
            "image" -> "$col = $image"
            "video" -> "$col = $video"
            else -> "$col IN ($image, $video)"
        }
    }

    private fun queryAssets(
        type: String,
        page: Int,
        pageSize: Int,
        albumId: String?,
        ascending: Boolean,
        startDate: Long?,
        endDate: Long?,
    ): List<Map<String, Any?>> {
        val collection = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.Files.FileColumns.DATE_ADDED,
            "datetaken",
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.WIDTH,
            MediaStore.Files.FileColumns.HEIGHT,
            "duration",
        )
        var selection = mediaTypeSelection(type)
        val args = mutableListOf<String>()
        if (albumId != null) {
            selection += " AND bucket_id = ?"
            args.add(albumId)
        }
        if (startDate != null && endDate != null) {
            // Filter on capture time (like iOS creationDate); fall back to the
            // time the file was added when the capture time is unknown.
            selection += " AND ((datetaken BETWEEN ? AND ?) OR " +
                "(datetaken IS NULL AND date_added BETWEEN ? AND ?))"
            args.add((startDate * 1000).toString())
            args.add((endDate * 1000 + 999).toString())
            args.add(startDate.toString())
            args.add(endDate.toString())
        }
        val selectionArgs = if (args.isEmpty()) null else args.toTypedArray()
        val offset = page * pageSize
        val direction = if (ascending) "ASC" else "DESC"
        // _ID breaks ties between items added in the same second so pages
        // never overlap or skip rows.
        val sortColumns = arrayOf(
            MediaStore.Files.FileColumns.DATE_ADDED,
            MediaStore.Files.FileColumns._ID,
        )

        val cursor = if (Build.VERSION.SDK_INT >= 30) {
            val bundle = Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                selectionArgs?.let {
                    putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, it)
                }
                // SQL order, not QUERY_ARG_SORT_COLUMNS: some OEM MediaStores
                // (seen on MIUI / Android 16) ignore the column form and fall
                // back to row order.
                putString(
                    ContentResolver.QUERY_ARG_SQL_SORT_ORDER,
                    sortColumns.joinToString(", ") { "$it $direction" },
                )
                putInt(ContentResolver.QUERY_ARG_LIMIT, pageSize)
                putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
            }
            context.contentResolver.query(collection, projection, bundle, null)
        } else {
            val sortOrder = sortColumns.joinToString(", ") { "$it $direction" } +
                " LIMIT $pageSize OFFSET $offset"
            context.contentResolver.query(
                collection, projection, selection, selectionArgs, sortOrder,
            )
        } ?: return emptyList()

        val list = mutableListOf<Map<String, Any?>>()
        cursor.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val typeCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED)
            val takenCol = c.getColumnIndex("datetaken")
            val nameCol = c.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeCol = c.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
            val widthCol = c.getColumnIndex(MediaStore.Files.FileColumns.WIDTH)
            val heightCol = c.getColumnIndex(MediaStore.Files.FileColumns.HEIGHT)
            val durationCol = c.getColumnIndex("duration")

            fun longOrNull(col: Int) = if (col >= 0 && !c.isNull(col)) c.getLong(col) else null

            while (c.moveToNext()) {
                val isVideo =
                    c.getInt(typeCol) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
                val dateAdded = c.getLong(dateCol)
                list.add(
                    mapOf(
                        "id" to c.getLong(idCol),
                        "type" to if (isVideo) "video" else "image",
                        "dateAdded" to dateAdded,
                        "dateTaken" to (longOrNull(takenCol)?.div(1000) ?: dateAdded),
                        "name" to if (nameCol >= 0) c.getString(nameCol) else null,
                        "sizeBytes" to longOrNull(sizeCol),
                        "width" to (longOrNull(widthCol) ?: 0L),
                        "height" to (longOrNull(heightCol) ?: 0L),
                        "durationMs" to
                            ((if (isVideo) longOrNull(durationCol) else null) ?: 0L),
                    ),
                )
            }
        }
        return list
    }

    // ---------------------------------------------------------------- albums

    /**
     * Groups media by MediaStore bucket (folder) in one pass over a light
     * projection, newest first, so the first row seen per bucket is its cover
     * and albums come out newest-cover-first.
     */
    private fun queryAlbums(type: String): List<Map<String, Any?>> {
        val collection = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            "bucket_id",
            "bucket_display_name",
        )
        val cursor = context.contentResolver.query(
            collection,
            projection,
            mediaTypeSelection(type),
            null,
            "${MediaStore.Files.FileColumns.DATE_ADDED} DESC, ${MediaStore.Files.FileColumns._ID} DESC",
        ) ?: return emptyList()

        class AlbumAcc(val name: String?, val coverId: Long, val coverType: String) {
            var count = 1
        }

        val albums = LinkedHashMap<String, AlbumAcc>()
        cursor.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val typeCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val bucketIdCol = c.getColumnIndex("bucket_id")
            val bucketNameCol = c.getColumnIndex("bucket_display_name")
            if (bucketIdCol < 0) return emptyList()

            while (c.moveToNext()) {
                val bucketId = c.getString(bucketIdCol) ?: continue
                val existing = albums[bucketId]
                if (existing != null) {
                    existing.count++
                    continue
                }
                val isVideo =
                    c.getInt(typeCol) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
                albums[bucketId] = AlbumAcc(
                    name = if (bucketNameCol >= 0) c.getString(bucketNameCol) else null,
                    coverId = c.getLong(idCol),
                    coverType = if (isVideo) "video" else "image",
                )
            }
        }
        return albums.map { (id, a) ->
            mapOf(
                "id" to id,
                "name" to a.name,
                "count" to a.count,
                "coverId" to a.coverId,
                "coverType" to a.coverType,
            )
        }
    }

    // ------------------------------------------------------------- thumbnail

    private fun contentUriFor(type: String, id: Long): Uri {
        val base = if (type == "video") {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        return ContentUris.withAppendedId(base, id)
    }

    private fun loadThumbnail(id: Long, type: String, size: Int): ByteArray? {
        val bitmap: Bitmap = if (Build.VERSION.SDK_INT >= 29) {
            context.contentResolver.loadThumbnail(contentUriFor(type, id), Size(size, size), null)
        } else {
            @Suppress("DEPRECATION")
            if (type == "video") {
                MediaStore.Video.Thumbnails.getThumbnail(
                    context.contentResolver, id, MediaStore.Video.Thumbnails.MINI_KIND, null,
                )
            } else {
                MediaStore.Images.Thumbnails.getThumbnail(
                    context.contentResolver, id, MediaStore.Images.Thumbnails.MINI_KIND, null,
                )
            }
        } ?: return null

        val oriented = if (type == "video") bitmap else applyOrientation(id, bitmap)
        val stream = ByteArrayOutputStream()
        oriented.compress(Bitmap.CompressFormat.JPEG, 80, stream)
        if (oriented !== bitmap) oriented.recycle()
        bitmap.recycle()
        return stream.toByteArray()
    }

    /**
     * Some OEM MediaStores (seen on MIUI / Android 16 with iPhone HEICs) hand
     * back thumbnails without the EXIF rotation applied. MediaStore's WIDTH /
     * HEIGHT are the raw sensor size, so a 90/270 image whose thumbnail still
     * has the raw aspect ratio was not rotated yet. 180 can't be detected this
     * way and is left as is.
     */
    private fun applyOrientation(id: Long, bitmap: Bitmap): Bitmap {
        val projection = arrayOf(
            MediaStore.Images.ImageColumns.ORIENTATION,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
        )
        val uri = contentUriFor("image", id)
        val (degrees, rawW, rawH) = context.contentResolver
            .query(uri, projection, null, null, null)?.use { c ->
                if (!c.moveToFirst()) return bitmap
                Triple(c.getInt(0), c.getInt(1), c.getInt(2))
            } ?: return bitmap
        if ((degrees != 90 && degrees != 270) || rawW <= 0 || rawH <= 0 || rawW == rawH) {
            return bitmap
        }
        val stillRaw = (bitmap.width > bitmap.height) == (rawW > rawH)
        if (!stillRaw) return bitmap
        val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    // ----------------------------------------------------------- file path

    private fun cacheDir() = File(context.cacheDir, CACHE_DIR)

    /** Deletes copies older than a day so the cache can't grow forever. */
    private fun purgeStaleCache() {
        val cutoff = System.currentTimeMillis() - CACHE_MAX_AGE_MS
        cacheDir().listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
    }

    private fun resolveOriginalPath(id: Long, type: String): String? {
        val uri = contentUriFor(type, id)

        // 1) Fast path: the DATA column still points to a readable file for
        //    MediaStore-owned media on most devices.
        @Suppress("DEPRECATION")
        context.contentResolver.query(
            uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null,
        )?.use { c ->
            if (c.moveToFirst()) {
                val p = c.getString(0)
                if (!p.isNullOrEmpty() && File(p).canRead()) return p
            }
        }

        // 2) Scoped-storage-safe fallback: copy the stream into the cache.
        var name = "media_$id"
        context.contentResolver.query(
            uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null,
        )?.use { c ->
            if (c.moveToFirst()) c.getString(0)?.let { name = it.replace('/', '_') }
        }
        val dir = cacheDir().apply { mkdirs() }
        val out = File(dir, "picker_${id}_$name")
        if (out.exists()) return out.absolutePath

        // Write to a temp file and rename, so an interrupted copy never
        // leaves a truncated file that later calls would trust.
        val part = File(dir, "${out.name}.part")
        try {
            val input = context.contentResolver.openInputStream(uri) ?: return null
            input.use { src -> part.outputStream().use { dst -> src.copyTo(dst) } }
            if (!part.renameTo(out)) return null
        } finally {
            part.delete()
        }
        return out.absolutePath
    }

    // --------------------------------------------------------- gallery changes

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        if (observer != null) return
        observer = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean) {
                // MediaStore fires a burst of notifications per import.
                mainHandler.removeCallbacks(emitChange)
                mainHandler.postDelayed(emitChange, CHANGE_DEBOUNCE_MS)
            }
        }.also {
            context.contentResolver.registerContentObserver(
                MediaStore.Files.getContentUri("external"), true, it,
            )
        }
    }

    override fun onCancel(arguments: Any?) {
        mainHandler.removeCallbacks(emitChange)
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
        eventSink = null
    }
}
