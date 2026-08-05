// TODO: change this to your app's package (same package as MainActivity),
// e.g. package com.yourcompany.yourapp
package com.example.media_picker_demo

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Native side of the "custom_media_picker" MethodChannel.
 *
 * Methods:
 *  - checkPermission              -> "granted" | "limited" | "notDetermined" | "denied"
 *  - requestPermission            -> "granted" | "limited" | "denied"
 *  - openAppSettings              -> Boolean
 *  - getAssets(type, page, size, albumId?, ascending?, startDate?, endDate?) -> List<Map>
 *  - getAlbums(type)              -> List<Map> (bucket albums)
 *  - getThumbnail(id, type, size) -> ByteArray (JPEG)
 *  - getOriginalPath(id, type)    -> String absolute path
 */
class MediaPickerHandler(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "custom_media_picker"
        const val PERMISSION_REQUEST_CODE = 4821
    }

    // Query/decoding work happens off the main thread; results are
    // delivered back on the main thread as required by Flutter.
    private val executor = Executors.newFixedThreadPool(3)
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> checkPermission(result)

            "requestPermission" -> requestPermission(result)

            "openAppSettings" -> openAppSettings(result)

            "getAssets" -> {
                val type = call.argument<String>("type") ?: "all"
                val page = call.argument<Int>("page") ?: 0
                val pageSize = call.argument<Int>("pageSize") ?: 60
                val albumId = call.argument<Any>("albumId")?.toString()
                val ascending = call.argument<Boolean>("ascending") ?: false
                val startDate = call.argument<Any>("startDate")?.toString()?.toLongOrNull()
                val endDate = call.argument<Any>("endDate")?.toString()?.toLongOrNull()
                executor.execute {
                    try {
                        val assets = queryAssets(
                            type, page, pageSize, albumId, ascending, startDate, endDate,
                        )
                        activity.runOnUiThread { result.success(assets) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("QUERY_ERROR", e.message, null)
                        }
                    }
                }
            }

            "getAlbums" -> {
                val type = call.argument<String>("type") ?: "all"
                executor.execute {
                    try {
                        val albums = queryAlbums(type)
                        activity.runOnUiThread { result.success(albums) }
                    } catch (e: Exception) {
                        activity.runOnUiThread {
                            result.error("QUERY_ERROR", e.message, null)
                        }
                    }
                }
            }

            "getThumbnail" -> {
                val id = call.argument<Any>("id")?.toString()?.toLongOrNull()
                val type = call.argument<String>("type") ?: "image"
                val size = call.argument<Int>("size") ?: 256
                if (id == null) {
                    result.error("BAD_ARGS", "id is required", null)
                    return
                }
                executor.execute {
                    val bytes = try {
                        loadThumbnail(id, type, size)
                    } catch (e: Exception) {
                        null
                    }
                    activity.runOnUiThread { result.success(bytes) }
                }
            }

            "getOriginalPath" -> {
                val id = call.argument<Any>("id")?.toString()?.toLongOrNull()
                val type = call.argument<String>("type") ?: "image"
                if (id == null) {
                    result.error("BAD_ARGS", "id is required", null)
                    return
                }
                executor.execute {
                    val path = try {
                        resolveOriginalPath(id, type)
                    } catch (e: Exception) {
                        null
                    }
                    activity.runOnUiThread { result.success(path) }
                }
            }

            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------ permission

    private fun requiredPermissions(): Array<String> {
        return when {
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
    }

    private fun hasFullAccess(): Boolean {
        val perms = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        return perms.all {
            ContextCompat.checkSelfPermission(activity, it) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasPartialAccess(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return false
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Current status without prompting. "notDetermined" is reported while the
     * system dialog has never been shown, so callers can tell a first run from
     * a user who already refused and now has to go through Settings.
     */
    private fun checkPermission(result: MethodChannel.Result) {
        result.success(
            when {
                hasFullAccess() -> "granted"
                hasPartialAccess() -> "limited"
                requiredPermissions().any {
                    ActivityCompat.shouldShowRequestPermissionRationale(activity, it)
                } -> "denied"
                else -> "notDetermined"
            },
        )
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasFullAccess()) {
            result.success("granted")
            return
        }
        if (hasPartialAccess()) {
            result.success("limited")
            return
        }
        if (pendingPermissionResult != null) {
            // A request is already in flight; don't stack another.
            result.success("denied")
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            requiredPermissions(),
            PERMISSION_REQUEST_CODE,
        )
    }

    /** Call from MainActivity.onRequestPermissionsResult. Returns true if handled. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val pending = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        val status = when {
            hasFullAccess() -> "granted"
            hasPartialAccess() -> "limited"
            grantResults.any { it == PackageManager.PERMISSION_GRANTED } -> "limited"
            else -> "denied"
        }
        pending.success(status)
        return true
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // ----------------------------------------------------------------- query

    private fun mediaTypeSelection(type: String): String {
        return when (type) {
            "image" ->
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} = " +
                    "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}"
            "video" ->
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} = " +
                    "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO}"
            else ->
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
                    "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}, " +
                    "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})"
        }
    }

    private fun queryAssets(
        type: String,
        page: Int,
        pageSize: Int,
        albumId: String? = null,
        ascending: Boolean = false,
        startDate: Long? = null,
        endDate: Long? = null,
    ): List<Map<String, Any?>> {
        val collection = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.Files.FileColumns.DATE_ADDED,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.WIDTH,
            MediaStore.Files.FileColumns.HEIGHT,
            "duration", // present for videos; guarded below
        )
        var selection = mediaTypeSelection(type)
        val selectionArgsList = mutableListOf<String>()
        if (albumId != null) {
            selection += " AND bucket_id = ?"
            selectionArgsList.add(albumId)
        }
        if (startDate != null && endDate != null) {
            selection += " AND ${MediaStore.Files.FileColumns.DATE_ADDED} BETWEEN ? AND ?"
            selectionArgsList.add(startDate.toString())
            selectionArgsList.add(endDate.toString())
        }
        val selectionArgs =
            if (selectionArgsList.isEmpty()) null else selectionArgsList.toTypedArray()
        val offset = page * pageSize

        val cursor = if (Build.VERSION.SDK_INT >= 30) {
            val args = Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                if (selectionArgs != null) {
                    putStringArray(
                        ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS,
                        selectionArgs,
                    )
                }
                putStringArray(
                    ContentResolver.QUERY_ARG_SORT_COLUMNS,
                    arrayOf(MediaStore.Files.FileColumns.DATE_ADDED),
                )
                putInt(
                    ContentResolver.QUERY_ARG_SORT_DIRECTION,
                    if (ascending) {
                        ContentResolver.QUERY_SORT_DIRECTION_ASCENDING
                    } else {
                        ContentResolver.QUERY_SORT_DIRECTION_DESCENDING
                    },
                )
                putInt(ContentResolver.QUERY_ARG_LIMIT, pageSize)
                putInt(ContentResolver.QUERY_ARG_OFFSET, offset)
            }
            activity.contentResolver.query(collection, projection, args, null)
        } else {
            val sortOrder =
                "${MediaStore.Files.FileColumns.DATE_ADDED} ${if (ascending) "ASC" else "DESC"} " +
                    "LIMIT $pageSize OFFSET $offset"
            activity.contentResolver.query(
                collection, projection, selection, selectionArgs, sortOrder,
            )
        } ?: return emptyList()

        val list = mutableListOf<Map<String, Any?>>()
        cursor.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val typeCol =
                c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val dateCol =
                c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED)
            val nameCol =
                c.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeCol = c.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
            val widthCol = c.getColumnIndex(MediaStore.Files.FileColumns.WIDTH)
            val heightCol = c.getColumnIndex(MediaStore.Files.FileColumns.HEIGHT)
            val durationCol = c.getColumnIndex("duration")

            while (c.moveToNext()) {
                val mediaType = c.getInt(typeCol)
                val isVideo =
                    mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
                list.add(
                    mapOf(
                        "id" to c.getLong(idCol),
                        "type" to if (isVideo) "video" else "image",
                        "dateAdded" to c.getLong(dateCol),
                        "name" to
                            if (nameCol >= 0) c.getString(nameCol) else null,
                        "sizeBytes" to
                            if (sizeCol >= 0) c.getLong(sizeCol) else null,
                        "width" to if (widthCol >= 0) c.getInt(widthCol) else 0,
                        "height" to
                            if (heightCol >= 0) c.getInt(heightCol) else 0,
                        "durationMs" to
                            if (isVideo && durationCol >= 0 &&
                                !c.isNull(durationCol)
                            ) c.getLong(durationCol) else 0L,
                    ),
                )
            }
        }
        return list
    }

    // ---------------------------------------------------------------- albums

    /**
     * Groups media by MediaStore bucket (folder). Single pass over a
     * light projection (IDs only), newest first, so the first row seen
     * per bucket is also its cover.
     */
    private fun queryAlbums(type: String): List<Map<String, Any?>> {
        val collection = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            "bucket_id",
            "bucket_display_name",
        )
        val selection = mediaTypeSelection(type)
        val sortOrder = "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"

        val cursor = activity.contentResolver.query(
            collection, projection, selection, null, sortOrder,
        ) ?: return emptyList()

        // LinkedHashMap keeps insertion order = newest-cover-first albums.
        data class AlbumAcc(
            val name: String,
            val coverId: Long,
            val coverType: String,
            var count: Int,
        )

        val albums = LinkedHashMap<String, AlbumAcc>()
        cursor.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val typeCol =
                c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val bucketIdCol = c.getColumnIndex("bucket_id")
            val bucketNameCol = c.getColumnIndex("bucket_display_name")
            if (bucketIdCol < 0) return emptyList()

            while (c.moveToNext()) {
                val bucketId = c.getString(bucketIdCol) ?: continue
                val existing = albums[bucketId]
                if (existing != null) {
                    existing.count++
                } else {
                    val isVideo = c.getInt(typeCol) ==
                        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
                    albums[bucketId] = AlbumAcc(
                        name = (if (bucketNameCol >= 0) {
                            c.getString(bucketNameCol)
                        } else null) ?: "Unknown",
                        coverId = c.getLong(idCol),
                        coverType = if (isVideo) "video" else "image",
                        count = 1,
                    )
                }
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
        val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= 29) {
            activity.contentResolver.loadThumbnail(
                contentUriFor(type, id), Size(size, size), null,
            )
        } else {
            @Suppress("DEPRECATION")
            if (type == "video") {
                MediaStore.Video.Thumbnails.getThumbnail(
                    activity.contentResolver, id,
                    MediaStore.Video.Thumbnails.MINI_KIND, null,
                )
            } else {
                MediaStore.Images.Thumbnails.getThumbnail(
                    activity.contentResolver, id,
                    MediaStore.Images.Thumbnails.MINI_KIND, null,
                )
            }
        } ?: return null

        val stream = ByteArrayOutputStream()
        bitmap!!.compress(Bitmap.CompressFormat.JPEG, 80, stream)
        bitmap.recycle()
        return stream.toByteArray()
    }

    // ----------------------------------------------------------- file path

    private fun resolveOriginalPath(id: Long, type: String): String? {
        val uri = contentUriFor(type, id)

        // 1) Fast path: the DATA column still points to a readable file
        //    for MediaStore-owned media on virtually all devices.
        @Suppress("DEPRECATION")
        activity.contentResolver.query(
            uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null,
        )?.use { c ->
            if (c.moveToFirst()) {
                val p = c.getString(0)
                if (!p.isNullOrEmpty() && File(p).canRead()) return p
            }
        }

        // 2) Scoped-storage-safe fallback: copy the stream into cacheDir.
        var name = "media_$id"
        activity.contentResolver.query(
            uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null, null, null,
        )?.use { c ->
            if (c.moveToFirst()) c.getString(0)?.let { name = it }
        }
        val out = File(activity.cacheDir, "picker_${id}_$name")
        if (out.exists() && out.length() > 0) return out.absolutePath
        activity.contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        return out.absolutePath
    }
}
