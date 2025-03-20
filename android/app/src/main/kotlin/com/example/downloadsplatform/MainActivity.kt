package com.example.downloadsplatform

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.AsyncTask
import android.os.Build
import android.os.Bundle
import android.util.Rational
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.Manifest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "native_thumbnail"
    private val PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the method channel for thumbnail generation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "generateThumbnail") {
                val videoPath = call.argument<String>("videoPath")
                val thumbnailPath = call.argument<String>("thumbnailPath")
                val maxWidth = call.argument<Int>("maxWidth") ?: 200
                val quality = call.argument<Int>("quality") ?: 80

                if (videoPath != null && thumbnailPath != null) {
                    generateVideoThumbnail(videoPath, thumbnailPath, maxWidth, quality, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Video path or thumbnail path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun generateVideoThumbnail(videoPath: String, thumbnailPath: String, maxWidth: Int, quality: Int, result: MethodChannel.Result) {
        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(videoPath)

            // Get the middle frame of the video
            val time = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0
            val middleTime = time / 2000

            val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(
                    middleTime * 1000,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    maxWidth,
                    maxWidth
                )
            } else {
                retriever.getFrameAtTime(middleTime * 1000)
            }

            if (bitmap != null) {
                val thumbnailFile = File(thumbnailPath)
                val out = FileOutputStream(thumbnailFile)
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                out.flush()
                out.close()
                result.success(thumbnailPath)
            } else {
                result.error("THUMBNAIL_ERROR", "Could not extract thumbnail from video", null)
            }

            retriever.release()
        } catch (e: Exception) {
            result.error("THUMBNAIL_ERROR", "Error generating thumbnail: ${e.message}", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Request necessary permissions
        requestRequiredPermissions()

        // Configure PiP mode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val aspectRatio = Rational(16, 9)
            val pipParams = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                .build()
            setPictureInPictureParams(pipParams)
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        )

        // For Android 10+ (API 29+), we need to handle storage differently
        val permissionsToRequest = mutableListOf<String>()

        for (permission in permissions) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(permission)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)

        // Send event to Flutter through EventChannel if needed
        // This could be connected to a separate MethodChannel to notify Flutter about PiP mode changes
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST_CODE) {
            // Handle permission results if needed
        }
    }
}