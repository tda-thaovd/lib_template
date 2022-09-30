import 'dart:async';
import 'dart:convert';

import 'package:camera_stream/model/question.dart';
import 'package:camera_stream/types/camera.dart';
import 'package:camera_stream/types/camera_exception.dart';
import 'package:camera_stream/types/features.dart';
import 'package:camera_stream/model/video_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef CameraStreamViewCreatedCallback = void Function(
    CameraStreamViewController);
typedef PermissionSetCallback = void Function(CameraStreamViewController, bool);

class CameraStreamView extends StatefulWidget {
  const CameraStreamView(
      {required Key key,
      required this.onCameraStreamViewCreated,
      this.cameraFacing = CameraFacing.front,
      this.onPermissionSet,
      this.warmup = false,
      this.questionData})
      : super(key: key);

  /// [onQRViewCreated] gets called when the view is created
  final CameraStreamViewCreatedCallback onCameraStreamViewCreated;

  /// Set which camera to use on startup.
  ///
  /// [cameraFacing] can either be CameraFacing.front or CameraFacing.back.
  /// Defaults to CameraFacing.back
  final CameraFacing cameraFacing;

  /// Calls the provided [onPermissionSet] callback when the permission is set.
  final PermissionSetCallback? onPermissionSet;

  /// Set record flow (warmup or normal)
  final bool warmup;

  final List<QuestionData>? questionData;

  @override
  State<StatefulWidget> createState() => _CameraStreamViewState();
}

class _CameraStreamViewState extends State<CameraStreamView> {
  late MethodChannel _channel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _getPlatformQrView(),
        Container(),
      ],
    );
  }

  Widget _getPlatformQrView() {
    Widget _platformQrView;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _platformQrView = AndroidView(
          viewType: 'jp.oyster.camera_stream/camera',
          onPlatformViewCreated: _onPlatformViewCreated,
          creationParams:
              _CameraSettings(cameraFacing: widget.cameraFacing).toMap(),
          creationParamsCodec: const StandardMessageCodec(),
        );
        break;
      case TargetPlatform.iOS:
        _platformQrView = UiKitView(
          viewType: 'jp.oyster.camera_stream/camera',
          onPlatformViewCreated: _onPlatformViewCreated,
          creationParams:
              _CameraSettings(cameraFacing: widget.cameraFacing).toMap(),
          creationParamsCodec: const StandardMessageCodec(),
        );
        break;
      default:
        throw UnsupportedError(
            "Trying to use the default webview implementation for $defaultTargetPlatform but there isn't a default one");
    }
    return _platformQrView;
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('jp.oyster.camera_stream/camera_$id');

    // Start record flow after creation of the view
    if (widget.key is GlobalKey<State<StatefulWidget>>) {
      final controller = CameraStreamViewController._(
          _channel,
          widget.key as GlobalKey<State<StatefulWidget>>?,
          widget.onPermissionSet,
          widget.cameraFacing)
        ..startRecordFlow(widget.key! as GlobalKey<State<StatefulWidget>>,
            widget.warmup, widget.questionData);

      // Initialize the controller for controlling the CameraStreamView
      widget.onCameraStreamViewCreated(controller);
    }
  }
}

class _CameraSettings {
  _CameraSettings({
    this.cameraFacing = CameraFacing.front,
  });

  final CameraFacing cameraFacing;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cameraFacing': cameraFacing.index,
    };
  }
}

class CameraStreamViewController {
  final MethodChannel _channel;
  final CameraFacing _cameraFacing;
  bool _hasPermissions = false;

  bool get hasPermissions => _hasPermissions;
  final StreamController<List<VideoInfo>> _recordUpdateController =
      StreamController<List<VideoInfo>>();

  Stream<List<VideoInfo>> get recordedDataStream =>
      _recordUpdateController.stream;

  CameraStreamViewController._(MethodChannel channel, GlobalKey? qrKey,
      PermissionSetCallback? onPermissionSet, CameraFacing cameraFacing)
      : _channel = channel,
        _cameraFacing = cameraFacing {
    // Listen callback from plugin
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onRecordComplete':
          if (call.arguments != null && call.arguments is String) {
            Iterable list = json.decode(call.arguments);
            List<VideoInfo> videoList = List<VideoInfo>.from(
                list.map((model) => VideoInfo.fromJson(model)));

            _recordUpdateController.sink.add(videoList);
          }
          break;
        case 'onRecordError':
          break;
        case 'onWarmUpComplete':
          if (call.arguments != null && call.arguments is String) {
            List<VideoInfo> outputs = <VideoInfo>[];
            var parsedJson = json.decode(call.arguments);
            outputs.add(VideoInfo.fromJson(parsedJson));
            _recordUpdateController.sink.add(outputs);
          }
          break;
        case 'onPermissionSet':
          if (call.arguments != null && call.arguments is bool) {
            _hasPermissions = call.arguments == true;
            if (onPermissionSet != null) {
              onPermissionSet(this, _hasPermissions);
            }
          }
          break;
      }
    });
  }

  /// Starts record flow
  Future<void> startRecordFlow(
      GlobalKey key, bool warmup, List<QuestionData>? questionData) async {
    try {
      if (warmup) {
        return await _channel.invokeMethod(
            'startWarmUp', jsonEncode(questionData));
      } else {
        return await _channel.invokeMethod(
            'startRecordFlow', jsonEncode(questionData));
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Gets information about which camera is active.
  Future<CameraFacing> getCameraInfo() async {
    try {
      final cameraFacing = await _channel.invokeMethod('getCameraInfo') as int;
      if (cameraFacing == -1) return _cameraFacing;
      return CameraFacing
          .values[await _channel.invokeMethod('getCameraInfo') as int];
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stops the camera
  Future<void> stopRecordFlow() async {
    try {
      await _channel.invokeMethod('stopRecordFlow');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Returns which features are available on device.
  Future<SystemFeatures> getSystemFeatures() async {
    try {
      final features =
          await _channel.invokeMapMethod<String, dynamic>('getSystemFeatures');
      if (features != null) {
        return SystemFeatures.fromJson(features);
      }
      throw CameraException('Error', 'Could not get system features');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stops the camera and disposes the camera stream.
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.iOS) stopRecordFlow();
    _recordUpdateController.close();
  }
}
