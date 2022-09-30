//
//  CameraStreamViewFactory.swift
//  camera_stream
//
//  Created by Vũ Anh Đức on 26/08/2021.
//

import Foundation

public class CameraStreamViewFactory: NSObject, FlutterPlatformViewFactory {
    
    var registrar: FlutterPluginRegistrar?
    
    public init(withRegistrar registrar: FlutterPluginRegistrar){
        super.init()
        self.registrar = registrar
    }
    
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let params = args as! Dictionary<String, Double>
        
        // Register custom font
        fontRegister()
        
        return CameraStreamWrapperView(withFrame: frame, withRegistrar: registrar!, withId: viewId, params: params)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec(readerWriter: FlutterStandardReaderWriter())
    }
    
    private func fontRegister() {
        for font in CustomFont.allValues {
            let fontKey = registrar?.lookupKey(forAsset: font.rawValue, fromPackage: "camera_stream")
            let path = Bundle.main.path(forResource: fontKey, ofType: nil)
            if let fontData = NSData(contentsOfFile: path ?? "") {
                if let dataProvider = CGDataProvider(data: fontData) {
                    let fontRef = CGFont(dataProvider)
                    var errorRef: Unmanaged<CFError>? = nil
                    if let fr = fontRef {
                        CTFontManagerRegisterGraphicsFont(fr, &errorRef)
                    }
                }
                
            }
        }
    }
}
