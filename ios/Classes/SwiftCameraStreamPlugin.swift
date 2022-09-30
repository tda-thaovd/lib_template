import Flutter
import UIKit

public class SwiftCameraStreamPlugin: NSObject, FlutterPlugin {
    
    var factory: CameraStreamViewFactory
    
    public init(with registrar: FlutterPluginRegistrar) {
        self.factory = CameraStreamViewFactory(withRegistrar: registrar)
        registrar.register(factory, withId: "jp.oyster.camera_stream/camera")
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        registrar.addApplicationDelegate(SwiftCameraStreamPlugin(with: registrar))
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        
    }
    
}
