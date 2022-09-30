package jp.oyster.camera_stream.utils

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

object Shared {
    var activity: FlutterActivity? = null
    var binding: ActivityPluginBinding? = null
    var flutterBinding: FlutterPlugin.FlutterPluginBinding? = null
}
