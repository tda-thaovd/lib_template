package jp.oyster.camera_stream.utils

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.graphics.Bitmap
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.Log
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import jp.oyster.camera_stream.models.GraphicOverlay
import java.io.File
import io.flutter.FlutterInjector

import io.flutter.embedding.engine.loader.FlutterLoader




/**
 * Check rect inside GraphicOverlay
 */
fun GraphicOverlay.checkRectInsideBox(outsideBoxRect: Rect, insideRect: Rect, spaceInsideFree: Int = 50): Boolean {
    val x = translateX(this, insideRect.centerX().toFloat())
    val y = translateY(this, insideRect.centerY().toFloat())

    val left =
        x - scale(this, insideRect.width() / 2.0f).toInt()
    val top =
        y - scale(this, insideRect.height() / 2.0f).toInt()
    val right =
        x + scale(this, insideRect.width() / 2.0f).toInt()
    val bottom =
        y + scale(this, insideRect.height() / 2.0f).toInt()

    return outsideBoxRect.top < top + spaceInsideFree
            && outsideBoxRect.left < left + spaceInsideFree
            && outsideBoxRect.bottom > bottom - spaceInsideFree
            && outsideBoxRect.right > right - spaceInsideFree
}

fun File.writeBitmap(bitmap: Bitmap, format: Bitmap.CompressFormat, quality: Int) {
    outputStream().use { out ->
        bitmap.compress(format, quality, out)
        out.flush()
        out.close()
    }
}

fun getThumbnailImage(context: Context?, videoFileUri: Uri?, thumbnailFile: File?, onDone: () -> Unit) {
    if (context == null || videoFileUri == null) return
    Glide.with(context).asBitmap().override(200).load(videoFileUri)
        .into(object : CustomTarget<Bitmap>() {
            override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                thumbnailFile?.writeBitmap(resource, Bitmap.CompressFormat.PNG, 85)
                onDone.invoke()
            }

            override fun onLoadCleared(placeholder: Drawable?) { }
        })
}

fun getFont(context: Context?, fontType: NotoFontType): Typeface? {
    val fontPath: String = when (fontType) {
        NotoFontType.Medium -> "fonts/NotoSansCJKjp-Medium.otf"
        NotoFontType.Bold -> "fonts/NotoSansCJKjp-Bold.otf"
        NotoFontType.Black -> "fonts/NotoSansCJKjp-Black.otf"
        else -> "fonts/NotoSansCJKjp-Regular.otf"
    }
    Shared.flutterBinding?.let {
        val flutterFontPath = it.flutterAssets.getAssetFilePathByName(fontPath, "camera_stream")
        return Typeface.createFromAsset(context?.assets, flutterFontPath)
    }
    return null
}

/**
 * dip to px
 */
fun dip2px(context: Context, dpValue: Float): Int {
    val scale = context.resources.displayMetrics.density
    return (dpValue * scale + 0.5f).toInt()
}

/**
 * px to dp
 */
fun px2dip(context: Context, pxValue: Float): Int {
    val scale = context.resources.displayMetrics.density
    return (pxValue / scale + 0.5f).toInt()
}

enum class NotoFontType {
    Regular, Medium, Bold, Black
}
