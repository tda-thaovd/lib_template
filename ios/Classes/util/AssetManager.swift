import Foundation
import UIKit
import Photos

open class AssetManager {
    
    public static func getImage(_ name: String) -> UIImage {
        let traitCollection = UITraitCollection(displayScale: 3)
        var bundle = Bundle.init(for: SwiftCameraStreamPlugin.self)

        if let resource = bundle.resourcePath, let resourceBundle = Bundle(path: resource + "/Resources.bundle") {
          bundle = resourceBundle
        }

        return UIImage(named: name, in: bundle, compatibleWith: traitCollection) ?? UIImage()
      }
    
}
