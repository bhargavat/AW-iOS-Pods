//
//  UIDevice+Model.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public enum AspectRatio{
    case device_3_2
    case device_4_3
    case device_16_9
    case device_unknown
}


extension UIDevice {
    public func screenResolution() -> CGRect {
        return UIScreen.main.nativeBounds
    }
    
    public func aspectRatio() -> AspectRatio {
        let screen = screenResolution()
        let ratio = String.localizedStringWithFormat("%.1f", round((screen.height/screen.width)*10)/10)
        switch ratio {
        case "1.5":
            return .device_3_2
        case "1.8":
            return .device_16_9
        case "1.3":
            return .device_4_3
        default:
            return .device_unknown
        }
    }
}
