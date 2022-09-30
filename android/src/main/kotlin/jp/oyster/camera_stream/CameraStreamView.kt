package jp.oyster.camera_stream

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import com.google.gson.Gson
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import jp.oyster.camera_stream.camera.CameraRecordView
import jp.oyster.camera_stream.models.Question
import jp.oyster.camera_stream.utils.Shared
import jp.oyster.camera_stream.utils.fromJson

class CameraStreamView(messenger: BinaryMessenger,
                       private val id: Int,
                       private val params: HashMap<String, Any>?):
    PlatformView, MethodChannel.MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {

    private var cameraRecordView: CameraRecordView? = null
    private val channel: MethodChannel = MethodChannel(messenger, "jp.oyster.camera_stream/camera_$id")
    private var permissionGranted: Boolean = false
    private var gson = Gson()
    private var questions: List<Question>? = null

    init {
        channel.setMethodCallHandler(this)
        Shared.binding?.addRequestPermissionsResultListener(this)
        Shared.binding?.activity?.application?.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityPaused(activity: Activity) {
                cameraRecordView?.pausePreview()
            }

            override fun onActivityResumed(activity: Activity) {
                cameraRecordView?.resumePreview()
            }

            override fun onActivityStarted(activity: Activity) {
            }

            override fun onActivityDestroyed(activity: Activity) {
            }

            override fun onActivitySaveInstanceState(activity: Activity, bundle: Bundle) {
            }

            override fun onActivityStopped(activity: Activity) {
            }

            override fun onActivityCreated(activity: Activity, bundle: Bundle?) {
            }
        })
    }

    override fun getView(): View {
        return initCameraRecordView().apply {  }
    }

    private fun initCameraRecordView(): CameraRecordView {
        if (cameraRecordView == null) {
            Shared.activity?.let {
                cameraRecordView = CameraRecordView(it)
            }
        }
        cameraRecordView?.recordCallback = { result, outputs ->
            if (result) channel.invokeMethod("onRecordComplete", gson.toJson(outputs))
            else channel.invokeMethod("onRecordError", null)
        }
        cameraRecordView?.warmupCallback = { result, output ->
            output?.let {
                if (result) channel.invokeMethod("onWarmUpComplete", gson.toJson(it))
                else channel.invokeMethod("onRecordError", null)
            } ?: run {
                channel.invokeMethod("onRecordError", null)
            }
        }
        return cameraRecordView as CameraRecordView
    }

    override fun dispose() {
//        TODO("Not yet implemented")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "getPlatformVersion" -> getPlatformVersion(result)
            "requestPermissions" -> checkAndRequestPermission(result)
            "startRecordFlow" -> startRecordFlow(call.arguments as? String, result)
            "stopRecordFlow" -> stopRecordFlow()
            "getSystemFeatures" -> getSystemFeatures(result)
            "startWarmUp" -> startWarmUpFlow(call.arguments as? String, result)
            else -> result.notImplemented()
        }
    }

    private fun allPermissionsGranted(): Boolean {
        return permissionGranted ||
                Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                (Shared.activity?.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
                        && Shared.activity?.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED)
    }

    private fun checkAndRequestPermission(result: MethodChannel.Result?, warmUp: Boolean = false) {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                if (allPermissionsGranted()) {
                    permissionGranted = true
                    channel.invokeMethod("onPermissionSet", true)
                } else {
                    Shared.activity?.requestPermissions(
                        REQUIRED_PERMISSIONS,
                         if (warmUp) (REQUEST_CODE_PERMISSIONS_WARMUP + this.id)
                         else (REQUEST_CODE_PERMISSIONS + this.id))
                }
            }
            else -> {
                result?.error("cameraPermission", "Platform Version to low for camera permission check", null)
            }
        }
    }

    override  fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if(requestCode == REQUEST_CODE_PERMISSIONS + this.id) {
            return if (allPermissionsGranted()) {
                permissionGranted = true
                channel.invokeMethod("onPermissionSet", true)
                cameraRecordView?.startDetectAndRecord(questions)
                true
            } else {
                permissionGranted = false
                channel.invokeMethod("onPermissionSet", false)
                false
            }
        } else if (requestCode == REQUEST_CODE_PERMISSIONS_WARMUP + this.id) {
            return if (allPermissionsGranted()) {
                permissionGranted = true
                channel.invokeMethod("onPermissionSet", true)
                cameraRecordView?.startWarmUp(questions)
                true
            } else {
                permissionGranted = false
                channel.invokeMethod("onPermissionSet", false)
                false
            }
        }
        return false
    }

    private fun getPlatformVersion(result: MethodChannel.Result) {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
    }

    private fun recordViewNotSet(result: MethodChannel.Result) {
        result.error("404", "No camera stream view found", null)
    }

    private fun hasSystemFeature(feature: String): Boolean {
        return Shared.activity?.packageManager?.hasSystemFeature(feature) ?: false
    }

    private fun hasBackCamera(): Boolean {
        return hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
    }

    private fun hasFrontCamera(): Boolean {
        return hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT)
    }

    private fun startRecordFlow(json: String?, result: MethodChannel.Result) {
        json?.let {
            val listQuestion: List<Question> = gson.fromJson<List<Question>>(it)
            questions = listQuestion
            if (allPermissionsGranted()) {
                cameraRecordView?.startDetectAndRecord(listQuestion)
            } else {
                checkAndRequestPermission(result)
            }
        } ?: run {
            channel.invokeMethod("onRecordError", null)
        }
    }

    private fun startWarmUpFlow(json: String?, result: MethodChannel.Result) {
        json?.let {
            val listQuestion: List<Question> = gson.fromJson<List<Question>>(it)
            questions = listQuestion
            if (allPermissionsGranted()) {
                cameraRecordView?.startWarmUp(listQuestion)
            } else {
                checkAndRequestPermission(result)
            }
        } ?: run {
            channel.invokeMethod("onRecordError", null)
        }
    }

    private fun stopRecordFlow() {
        // TODO
    }

    private fun getSystemFeatures(result: MethodChannel.Result) {
        try {
            result.success(mapOf("hasFrontCamera" to hasFrontCamera(),
                "hasBackCamera" to hasBackCamera()))
        } catch (e: Exception) {
            result.error("", "", "")
        }
    }

    companion object {
        private val REQUIRED_PERMISSIONS =
            arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
        private const val REQUEST_CODE_PERMISSIONS = 6969
        private const val REQUEST_CODE_PERMISSIONS_WARMUP = 9696
    }

}
