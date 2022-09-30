import 'dart:developer';

import 'package:camera_stream/camera_stream_view.dart';
import 'package:camera_stream/model/question.dart';
import 'package:camera_stream/model/video_info.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Oyster - Camera Stream Sample',
                style: TextStyle(
                  fontFamily: 'NotoSansCJKjp-Bold',
                  letterSpacing: 0,
                  fontSize: 16,
                )),
          ),
          body: ListView.builder(
              itemCount: 1,
              itemBuilder: (context, rowNumber) {
                return new Container(
                  padding: EdgeInsets.all(16.0),
                  child: new Column(
                    children: <Widget>[
                      Center(
                        child: Text('Running on: ',
                            style: TextStyle(
                              fontFamily: 'NotoSansCJKjp-Medium',
                              letterSpacing: 0,
                              fontSize: 12,
                            )),
                      ),
                      new SizedBox(
                        height: 16.0,
                      ),
                      new MaterialButton(
                          child: const Text(
                            'Start Warm up',
                            style: TextStyle(
                              fontFamily: 'NotoSansCJKjp-Bold',
                              letterSpacing: 0,
                              fontSize: 15,
                            ),
                          ),
                          elevation: 5.0,
                          height: 48.0,
                          minWidth: 250.0,
                          color: Colors.blue,
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => CameraStreamViewExample(
                                  key: GlobalKey(debugLabel: 'CameraStream'),
                                  warmup: true),
                            ));
                          }),
                      new SizedBox(
                        height: 16.0,
                      ),
                      new MaterialButton(
                          child: const Text('Start Interview Flow',
                              style: TextStyle(
                                fontFamily: 'NotoSansCJKjp-Bold',
                                letterSpacing: 0,
                                fontSize: 15,
                              )),
                          elevation: 5.0,
                          height: 48.0,
                          minWidth: 250.0,
                          color: Colors.blue,
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => CameraStreamViewExample(
                                  key: GlobalKey(debugLabel: 'CameraStream'),
                                  warmup: false),
                            ));
                          }),
                    ],
                  ),
                );
              })),
    );
  }
}

class CameraStreamViewExample extends StatefulWidget {
  const CameraStreamViewExample({required Key key, this.warmup = false})
      : super(key: key);

  /// Set record flow (warmup or normal)
  final bool warmup;

  @override
  State<StatefulWidget> createState() => _CameraStreamViewExampleState();
}

class _CameraStreamViewExampleState extends State<CameraStreamViewExample> {
  List<VideoInfo>? result;
  CameraStreamViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'CameraStream');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
              flex: 4, child: _buildCameraStreamView(context, widget.warmup)),
        ],
      ),
    );
  }

  Widget _buildCameraStreamView(BuildContext context, bool warmup) {
    return CameraStreamView(
        key: qrKey,
        onCameraStreamViewCreated: _onCameraStreamViewCreated,
        onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
        warmup: warmup,
        questionData: warmup ? generateWarmupData() : generateQuestionData());
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

  List<QuestionData> generateQuestionData() {
    return [
      QuestionData(
          '5ca34be2-6834-4296-96d0-e5c04c3d039d',
          'https://grrow-osyster-dev.s3.ap-northeast-1.amazonaws.com/audios/1.mp3',
          'Audio 1',
          30,
          1),
      QuestionData(
          '6ce3ede8-859e-4307-9979-c40b4a704861',
          'https://grrow-osyster-dev.s3.ap-northeast-1.amazonaws.com/audios/3.mp3',
          'Audio 3',
          20,
          3),
    ];
  }

  List<QuestionData> generateWarmupData() {
    return [
      QuestionData(
          '95cab3f1-0afb-41dd-add6-f4fdac92f039',
          'https://grrow-osyster-dev.s3.ap-northeast-1.amazonaws.com/audios/6.mp3',
          'Test',
          30,
          1)
    ];
  }
}
