package com.plotmetric.plotmetric

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.plotmetric.plotmetric/native"
    private val REQUEST_CODE_PICK_IMAGE = 1001
    private val REQUEST_CODE_TAKE_PHOTO = 1002
    private val REQUEST_CODE_OPEN_EXPORTS = 1003
    private val exportsFolder = "PlotMetric_Exports"

    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingCameraResult: MethodChannel.Result? = null
    private var photoCapturePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveExport" -> {
                    val name = call.argument<String>("fileName") ?: ""
                    val bytes = call.argument<ByteArray>("bytes")
                    if (name.isBlank() || name in listOf(".", "..") || File(name).name != name || bytes == null) {
                        result.error("INVALID_EXPORT", "Missing export name or data", null)
                        return@setMethodCallHandler
                    }
                    val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                    Thread {
                        try {
                            result.success(saveExport(name, mime, bytes))
                        } catch (e: Exception) {
                            result.error("SAVE_EXPORT_ERROR", e.message, null)
                        }
                    }.start()
                }
                "recognizeImageText", "recognizeImageTable" -> {
                    val path = call.argument<String>("filePath") ?: ""
                    recognizeImageText(File(path), call.method == "recognizeImageTable", result)
                }
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
                    val preferWhatsApp = call.argument<Boolean>("preferWhatsApp") == true
                    shareExport(filePath, mimeType, title, preferWhatsApp, result)
                }
                "openFile" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    try {
                        val uri = exportUri(filePath)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, contentResolver.getType(uri) ?: mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FILE_ERROR", e.message, null)
                    }
                }
                "openFolder" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    try {
                        if (!filePath.startsWith("content://")) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        openDownloadsFolder()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FOLDER_ERROR", e.message, null)
                    }
                }
                "pickImage" -> {
                    try {
                        pendingPickResult = result
                        val csvOnly = call.argument<Boolean>("csvOnly") == true
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, if (csvOnly)
                                arrayOf("text/csv", "text/plain", "application/csv", "application/vnd.ms-excel", "application/octet-stream")
                            else arrayOf("image/*", "text/plain", "text/csv"))
                        }
                        startActivityForResult(Intent.createChooser(intent,
                            if (csvOnly) "Select office register CSV" else "Select Image or Document"), REQUEST_CODE_PICK_IMAGE)
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

    private fun saveExport(name: String, mime: String, bytes: ByteArray): Map<String, String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val directory = File(filesDir, exportsFolder).apply { mkdirs() }
            val path = File(directory, name).apply { writeBytes(bytes) }.absolutePath
            return mapOf("reference" to path, "path" to path, "name" to name)
        }

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$exportsFolder/")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("Could not create file in Downloads")
        try {
            val stream = contentResolver.openOutputStream(uri) ?: error("Could not open export for writing")
            stream.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            check(contentResolver.update(uri, values, null, null) == 1) { "Could not publish export" }
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            throw e
        }
        val reference = uri.toString()
        val columns = arrayOf(MediaStore.MediaColumns.DATA, MediaStore.MediaColumns.DISPLAY_NAME)
        return try {
            contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    mapOf(
                        "reference" to reference,
                        "path" to (cursor.getString(0) ?: reference),
                        "name" to (cursor.getString(1) ?: name)
                    )
                } else null
            } ?: mapOf("reference" to reference, "path" to reference, "name" to name)
        } catch (_: IllegalArgumentException) {
            mapOf("reference" to reference, "path" to reference, "name" to name)
        }
    }

    private fun exportUri(filePath: String): Uri {
        if (filePath.startsWith("content://")) return Uri.parse(filePath)
        val file = File(filePath)
        check(file.isFile) { "Export file is missing" }
        return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
    }

    private fun shareExport(
        filePath: String,
        mimeType: String,
        title: String,
        preferWhatsApp: Boolean,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val source = exportUri(filePath)
                val actualType = contentResolver.getType(source) ?: mimeType
                val attachment = if (filePath.startsWith("content://")) stageAttachment(source) else source
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = if (actualType == "application/json") "application/octet-stream" else actualType
                    putExtra(Intent.EXTRA_STREAM, attachment)
                    clipData = ClipData.newUri(contentResolver, title, attachment)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                runOnUiThread {
                    try {
                        if (!preferWhatsApp || !openWhatsApp(intent)) {
                            startActivity(Intent.createChooser(intent, title).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            })
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_FILE_ERROR", e.message, null)
                    }
                }
            } catch (e: Exception) {
                result.error("SHARE_FILE_ERROR", e.message, null)
            }
        }.start()
    }

    private fun stageAttachment(source: Uri): Uri {
        // Use a named FileProvider URI because receivers can display a MediaStore ID as the filename.
        val displayName = contentResolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
        val name = File(displayName ?: error("Missing attachment name")).name
        check(name.isNotBlank() && name != "." && name != "..") { "Invalid attachment name" }
        val folder = File(cacheDir, "shared_exports/${UUID.randomUUID()}")
        check(folder.mkdirs()) { "Could not create attachment cache" }
        val file = File(folder, name)
        try {
            val input = contentResolver.openInputStream(source) ?: error("Could not read exported file")
            input.use { from -> file.outputStream().use { to -> from.copyTo(to) } }
            return FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        } catch (e: Exception) {
            file.delete()
            folder.delete()
            throw e
        }
    }

    private fun openDownloadsFolder() {
        val uri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:${Environment.DIRECTORY_DOWNLOADS}/$exportsFolder"
        )
        val openedFolder = try {
            startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
        if (!openedFolder) {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                type = "*/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
                }
            }, REQUEST_CODE_OPEN_EXPORTS)
        }
    }

    private fun openWhatsApp(attachment: Intent): Boolean {
        for (app in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            try {
                startActivity(Intent(attachment).setPackage(app))
                return true
            } catch (_: ActivityNotFoundException) {
                continue
            }
        }
        return false
    }

    private fun recognizeImageText(file: File, table: Boolean, result: MethodChannel.Result) {
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(file))
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image).addOnCompleteListener { task ->
                try {
                    if (task.isSuccessful) {
                        result.success(if (table) readTableWords(task.result) else readTextRows(task.result))
                    } else {
                        Log.w("PlotMetricOCR", "Image recognition failed", task.exception)
                        result.error("OCR_ERROR", task.exception?.message, null)
                    }
                } finally {
                    recognizer.close()
                }
            }
        } catch (e: Exception) {
            Log.w("PlotMetricOCR", "Could not start image recognition", e)
            result.error("OCR_ERROR", e.message, null)
        }
    }

    private fun readTableWords(text: Text): List<Map<String, Any>> {
        val lines = text.textBlocks.flatMap { it.lines }
        val edges = lines.mapNotNull { line ->
            line.cornerPoints?.takeIf { it.size >= 2 }?.let { it[0] to it[1] }
        }
        val width = edges.sumOf { (left, right) -> right.x - left.x }
        val slope = if (width > 0) edges.sumOf { (left, right) -> right.y - left.y }.toDouble() / width else 0.0
        return lines.flatMap { line ->
            line.elements.mapNotNull { word ->
                word.boundingBox?.let { box ->
                    mapOf(
                        "text" to word.text,
                        "x" to box.exactCenterX().toDouble(),
                        "y" to box.exactCenterY() - slope * box.exactCenterX(),
                        "height" to box.height()
                    )
                }
            }
        }
    }

    private fun readTextRows(text: Text): String {
        val lines = text.textBlocks.flatMap { it.lines }
        val edges = lines.mapNotNull { line ->
            line.cornerPoints?.takeIf { it.size >= 2 }?.let { it[0] to it[1] }
        }
        val width = edges.sumOf { (left, right) -> right.x - left.x }
        val slope = if (width > 0) edges.sumOf { (left, right) -> right.y - left.y }.toDouble() / width else 0.0
        val positioned = lines.mapNotNull { line -> line.boundingBox?.let { it to line.text } }
        fun rowCenter(box: android.graphics.Rect) = box.exactCenterY() - slope * box.exactCenterX()
        val rows = mutableListOf<MutableList<Pair<android.graphics.Rect, String>>>()
        for (line in positioned.sortedBy { rowCenter(it.first) }) {
            val previous = rows.lastOrNull()
            val anchor = previous?.firstOrNull()?.first
            val box = line.first
            // Table labels and values can be returned as separate text blocks.
            if (previous != null && anchor != null && kotlin.math.abs(rowCenter(box) - rowCenter(anchor)) <=
                minOf(anchor.height(), box.height()) * 0.65) {
                previous.add(line)
            } else {
                rows.add(mutableListOf(line))
            }
        }
        return (rows.map { row -> row.sortedBy { it.first.left }.joinToString(" ") { it.second } } +
            lines.filter { it.boundingBox == null }.map { it.text }).joinToString("\n")
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
