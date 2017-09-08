//
//  UIColor+Format.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

private let AWColorComponentRedKey:String = "Red"
private let AWColorComponentGreenKey:String	= "Green"
private let AWColorComponentBlueKey:String	= "Blue"
private let AWColorComponentAlphaKey:String	= "Alpha"

extension UIColor {
    
    public convenience init(number:Int) {
        
        let rgba: Int = number
        let redValue: Int = ((rgba & 0xff0000) >> 16)
        let greenValue: Int = ((rgba & 0x00ff00) >> 8)
        let blueValue:Int = (rgba & 0x0000ff)
        
        let red = CGFloat(redValue)/255.0
        let green = CGFloat(greenValue)/255.0
        let blue = CGFloat(blueValue)/255.0
        
        self.init(red: red, green:green, blue: blue, alpha:1.0)
    }
    
    @objc (AW_colorComponents)
    public func colorComponents() -> Dictionary<String,NSNumber> {
        var colorInfo: Dictionary<String,NSNumber> = Dictionary()
        if let components = self.cgColor.components {
            colorInfo[AWColorComponentRedKey] = NSNumber(value: Float((components[0])*255) as Float)
            colorInfo[AWColorComponentGreenKey] = NSNumber(value: Float((components[1])*255) as Float)
            colorInfo[AWColorComponentBlueKey] = NSNumber(value: Float((components[2])*255) as Float)
            colorInfo[AWColorComponentAlphaKey] = NSNumber(value: Float((components[3])) as Float)
        }
        return colorInfo;
    }
    
    func transformARGBToHex() -> UInt? {
        var fRed: CGFloat = 0
        var fGreen: CGFloat = 0
        var fBlue: CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iRed = UInt(fRed * 255.0)
            let iGreen = UInt(fGreen * 255.0)
            let iBlue = UInt(fBlue * 255.0)
            let iAlpha = UInt(fAlpha * 255.0)
            
            //  (Bits 24-31 are alpha, 16-23 are red, 8-15 are green, 0-7 are blue).
            let rgb = ((iAlpha & 0xFF) << 24) | ((iRed & 0xFF) << 16) | ((iGreen & 0xFF) << 8) | (iBlue & 0xFF)
            return rgb
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
}
