//
//  CameraStreamWrapperView.swift
//  camera_stream
//
//  Created by Vũ Anh Đức on 26/08/2021.
//

import Foundation

public class CameraStreamWrapperView: NSObject, FlutterPlatformView {
   
    var registrar: FlutterPluginRegistrar
    var channel: FlutterMethodChannel
    var cameraStreamView: CameraStreamView?
    
    public init(withFrame frame: CGRect, withRegistrar registrar: FlutterPluginRegistrar, withId id: Int64, params: Dictionary<String, Any>) {
        self.registrar = registrar
        
        // Init camera stream view
        cameraStreamView = CameraStreamView(frame: frame)
        cameraStreamView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        channel = FlutterMethodChannel(name: "jp.oyster.camera_stream/camera_\(id)", binaryMessenger: registrar.messenger())
    }
    
    deinit {
        cameraStreamView = nil
    }
    
    public func view() -> UIView {
        channel.setMethodCallHandler({
                   [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch(call.method) {
            case "startRecordFlow":
                self?.startRecordFlow(call.arguments as! String, result)
            case "startWarmUp":
                self?.startWarmUp(call.arguments as! String, result)
            case "stopRecordFlow":
                self?.stopRecordFlow(result)
            case "getSystemFeatures":
                self?.getSystemFeatures(result)
            default:
                result(FlutterMethodNotImplemented)
                return
            }
        })
        
        cameraStreamView?.recordVideoHandler = { videoInfos in
            print(videoInfos)
            self.channel.invokeMethod("onRecordComplete", arguments: videoInfos.toJSONString())
        }
        
        cameraStreamView?.warmUpHandler = { videoInfo in
            print(videoInfo.toJSONString())
            if let warmUpVideo = videoInfo {
                self.channel.invokeMethod("onWarmUpComplete", arguments: warmUpVideo.toJSONString())
            }
            
        }
        
        return cameraStreamView!
    }
    
    func startRecordFlow(_ arguments: String, _ result: @escaping FlutterResult) {
        if let questions = [Question].map(JSONString: arguments) {
            cameraStreamView?.startDetectAndRecord(questions: questions)
        }
    }
    
    func startWarmUp(_ arguments: String, _ result: @escaping FlutterResult) {
        if let questions = [Question].map(JSONString: arguments) {
            cameraStreamView?.startWarmUpFlow(warmUpQuestion: questions.first)
        }
    }
    
    func stopRecordFlow(_ result: @escaping FlutterResult) {
        cameraStreamView?.reset()
        cameraStreamView = nil
    }
    
    func getSystemFeatures(_ result: @escaping FlutterResult) {
    }
    
}

extension Decodable {
    
    static func map(JSONString: String) -> Self? {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Self.self, from: Data(JSONString.utf8))
        } catch let error {
            print(error)
            return nil
        }
    }
    
}

extension Encodable {
  func toJSONString() -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    do {
      let data = try encoder.encode(self)
      return String(data: data, encoding: .utf8)
    } catch {
      print(error)
      return nil
    }
  }
}

enum CustomFont: String {
     
    case Regular = "fonts/NotoSansCJKjp-Regular.otf"
    
    case Medium = "fonts/NotoSansCJKjp-Medium.otf"
    
    case Bold = "fonts/NotoSansCJKjp-Bold.otf"
     
    case Black = "fonts/NotoSansCJKjp-Black.otf"
     
    static let allValues = [Regular, Medium, Bold, Black]
     
}
