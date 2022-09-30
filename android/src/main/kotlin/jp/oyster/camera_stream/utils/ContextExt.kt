package jp.oyster.camera_stream.utils

import android.content.Context
import android.media.AudioManager
import android.widget.Toast
import androidx.annotation.DrawableRes
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

fun Context.toast(message: String, duration: Int = Toast.LENGTH_LONG) {
    Toast.makeText(
        this,
        message,
        duration
    ).show()
}

fun Context.getDrawableV2(@DrawableRes drawable: Int) = ContextCompat.getDrawable(this, drawable)

inline fun <reified T> Gson.fromJson(json: String) = fromJson<T>(json, object : TypeToken<T>() {}.type)
