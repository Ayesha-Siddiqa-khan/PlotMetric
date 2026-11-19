package com.plotmetric.plotmetric

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.plotmetric.plotmetric/native"
    private val REQUEST_CODE_PICK_IMAGE = 1001
    private val REQUEST_CODE_TAKE_PHOTO = 1002

    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var photoCapturePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val title = call.argument<String>("title") ?: "Share via"
                    try {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(intent, title))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    val title = call.argument<String>("title") ?: "Share File"
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, title))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_FILE_ERROR", e.message, null)
                    }
                }
                "openFile" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "Open with"))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FILE_ERROR", e.message, null)
                    }
                }
                "openFolder" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    try {
                        val file = File(filePath)
                        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "*/*")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "Open in Files"))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FOLDER_ERROR", e.message, null)
                    }
                }
                "pickImage" -> {
                    try {
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "text/plain", "text/csv"))
                        }
                        startActivityForResult(Intent.createChooser(intent, "Select Image or Document"), REQUEST_CODE_PICK_IMAGE)
                    } catch (e: Exception) {
                        pendingPickResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                "takePhoto" -> {
                    try {
                        pendingCameraResult = result
                        val photoFile = File(cacheDir, "scan_${System.currentTimeMillis()}.jpg")
                        photoCapturePath = photoFile.absolutePath
                        val photoUri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", photoFile)
                        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                            putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        }
                        startActivityForResult(intent, REQUEST_CODE_TAKE_PHOTO)
                    } catch (e: Exception) {
                        pendingCameraResult = null
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_IMAGE) {
            val res = pendingPickResult
            pendingPickResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val ext = getExtensionFromUri(uri)
                    val destFile = File(cacheDir, "picked_${System.currentTimeMillis()}.$ext")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    res?.success(destFile.absolutePath)
                } catch (e: Exception) {
                    res?.error("PICK_COPY_ERROR", e.message, null)
                }
            } else {
                res?.success(null)
            }
        } else if (requestCode == REQUEST_CODE_TAKE_PHOTO) {
            val res = pendingCameraResult
            pendingCameraResult = null
            if (resultCode == Activity.RESULT_OK && photoCapturePath != null) {
                val file = File(photoCapturePath!!)
                if (file.exists() && file.length() > 0) {
                    res?.success(photoCapturePath)
                } else {
                    res?.success(null)
                }
            } else {
                res?.success(null)
            }
        }
    }

    private fun getExtensionFromUri(uri: Uri): String {
        val mime = contentResolver.getType(uri)
        return when {
            mime?.contains("png") == true -> "png"
            mime?.contains("csv") == true -> "csv"
            mime?.contains("text") == true -> "txt"
            else -> "jpg"
        }
    }
}
