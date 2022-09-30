//
//  Common.swift
//  CameraModule
//
//  Created by Huy Nguyen on 25/08/2021.
//

import UIKit

enum Util {
    static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first

        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            return topController
        }
        
        return nil
    }
    
}
