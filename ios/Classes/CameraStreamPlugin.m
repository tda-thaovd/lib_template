#import "CameraStreamPlugin.h"
#if __has_include(<camera_stream/camera_stream-Swift.h>)
#import <camera_stream/camera_stream-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "camera_stream-Swift.h"
#endif

@implementation CameraStreamPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCameraStreamPlugin registerWithRegistrar:registrar];
}
@end
