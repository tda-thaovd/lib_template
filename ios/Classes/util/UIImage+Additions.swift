//
//  UIImage+Additions.swift
//  CameraModule
//
//  Created by Huy Nguyen on 25/08/2021.
//

import UIKit

extension UIImage {
    
    convenience init?(namedInCurrentBundle: String) {
        self.init(named: namedInCurrentBundle, in: Bundle.current, compatibleWith: nil)
    }
    
    func resized(withPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: size.width * percentage, height: size.height * percentage)
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
    
    func resized(toWidth width: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
    
}

extension Bundle {
    static var current: Bundle {
        Bundle(for: CameraStreamView.self)
    }
}

extension UIFont {

    public enum NotoSansCJKJSType: String {
        case bold = " Bold"
        case black = " Black"
        case medium = " Medium"
        case regular = " Regular"
    }

    static func NotoSansCJKJS(_ type: NotoSansCJKJSType = .regular, size: CGFloat = UIFont.systemFontSize) -> UIFont {
        return UIFont(name: "Noto Sans CJK JP\(type.rawValue)", size: size)!
    }

}
