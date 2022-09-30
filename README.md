# Camera Stream

Face detect and online interview flow of Oyster project that works on both iOS and Android by natively embedding the platform view within Flutter. The integration with Flutter is seamless, much better than jumping into a native Activity or a ViewController to perform the flow.

## Getting Started

Embed ```CameraStreamView``` into your code 

```dart
class _CameraStreamViewExampleState extends State<CameraStreamViewExample> {

  List<VideoInfo>? result;
  CameraStreamViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'CameraStream');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildCameraStreamView(context)),
        ],
      ),
    );
  }

  Widget _buildCameraStreamView(BuildContext context) {
    return CameraStreamView(
      key: qrKey,
      onCameraStreamViewCreated: _onCameraStreamViewCreated,
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onCameraStreamViewCreated(CameraStreamViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.recordedDataStream.listen((recordVideo) {
      print(recordVideo);
    });
  }

  void _onPermissionSet(
      BuildContext context, CameraStreamViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
```

## iOS Integration
In order to use this plugin, add the following to your Info.plist file:
```
<key>io.flutter.embedded_views_preview</key>
<true/>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>
```

## Start face detect and record interview flow

Record flow will be trigger after creation of the view

## Permission check and request

This module was self check and request required permissions but you can listen callback from your app

```dart
Widget _buildCameraStreamView(BuildContext context) {
    return CameraStreamView(
      key: qrKey,
      onCameraStreamViewCreated: _onCameraStreamViewCreated,
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onPermissionSet(
      BuildContext context, CameraStreamViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no Permission')),
      );
    }
  }
```

# SDK
Requires at least SDK 21 (Android 5.0).
Requires at least iOS 11.

# TODOs
* iOS version
* Add more arguments like video resolution, question list and so on.
* In future, options will be provided for default states.
