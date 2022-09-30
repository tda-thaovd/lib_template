package jp.oyster.camera_stream

import io.flutter.embedding.android.FlutterActivity

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformViewRegistry
import jp.oyster.camera_stream.utils.Shared

/** CameraStreamPlugin */
class CameraStreamPlugin : FlutterPlugin, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    onAttachedToEngines(binding.platformViewRegistry, binding.binaryMessenger, Shared.activity)
    Shared.flutterBinding = binding
  }

  private fun onAttachedToEngines(platformViewRegistry: PlatformViewRegistry, messenger: BinaryMessenger, activity: FlutterActivity?) {
    if (activity != null) {
      Shared.activity = activity
    }
    platformViewRegistry
      .registerViewFactory(
        "jp.oyster.camera_stream/camera", CameraStreamFactory(messenger))
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Shared.flutterBinding = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Shared.activity = binding.activity as FlutterActivity
    Shared.binding = binding
  }

  override fun onDetachedFromActivityForConfigChanges() {
    Shared.activity = null
    Shared.binding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    Shared.activity = binding.activity as FlutterActivity
    Shared.binding = binding
  }

  override fun onDetachedFromActivity() {
    Shared.activity = null
    Shared.binding = null
  }

}
