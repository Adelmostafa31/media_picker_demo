package com.example.media_picker_demo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaPickerHandler: MediaPickerHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaPickerHandler = MediaPickerHandler(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MediaPickerHandler.CHANNEL,
        ).setMethodCallHandler(mediaPickerHandler)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (mediaPickerHandler?.onRequestPermissionsResult(
                requestCode, grantResults) == true
        ) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
