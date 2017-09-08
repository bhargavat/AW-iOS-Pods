//
//  UIDevice+Power.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWLocalization
import Foundation

public enum AWDevicePowerLineType : Int8, SwiftEnumSerializable {
    case offline = 0x0
    case online  = 0x1
    case power   = 0x2
    case unknown  = 0xF
    
    public func data() throws -> Data {
        return dataFromInteger(self.rawValue)
    }
}

public enum AWDeviceBatteryStatus : UInt8, SwiftEnumSerializable {
    case high      = 0x01
    case low       = 0x02
    case critical  = 0x04
    case charging  = 0x08
    case noBattery = 0x80
    case unknown   = 0xFF
    
    public func data() throws -> Data {
        return dataFromInteger(self.rawValue)
    }
}

public enum AWDeviceBatteryChemistry : UInt8, SwiftEnumSerializable {
    case alkaline = 0x01
    case nicd     = 0x02
    case nimh     = 0x03
    case lion     = 0x04
    case lipoly   = 0x05
    case zincair  = 0x06
    case unknown  = 0xFF
    
    public func data() throws -> Data {
        return dataFromInteger(self.rawValue)
    }
}

public typealias AWDeviceBatteryLevel = UInt8

extension UIDevice {
    
    public func deviceBatteryState() -> UIDeviceBatteryState {
        return self.batteryState
    }
    
    public func deviceBatteryLevel() -> Float {
        return self.batteryLevel
    }
    
    public func powerLineType() -> AWDevicePowerLineType {
        var lineType: AWDevicePowerLineType
        
        let batteryState: UIDeviceBatteryState = deviceBatteryState()
        
        switch batteryState {
        case UIDeviceBatteryState.charging:   // Plugged In
            lineType = AWDevicePowerLineType.online
            
        case UIDeviceBatteryState.unplugged:  // Unplugged
            lineType = AWDevicePowerLineType.offline
            
        case UIDeviceBatteryState.full:
            // Device is plugged in and Battery is 100% charged
            // Return type is Online. Console expects plugged or unplugged status
            lineType = AWDevicePowerLineType.online
            
        default:
            lineType = AWDevicePowerLineType.unknown
        }
        
        return lineType
    }
    
    public func batteryLifePercent() -> AWDeviceBatteryLevel {
        
        let batteryLevel = deviceBatteryLevel()
        if batteryLevel <= 0 {
            return 0
        }
        return UInt8(batteryLevel * 100)
    }
    
    func batteryStateString() -> String {
        var batteryState: String? = nil
        
        switch deviceBatteryState() {
        case UIDeviceBatteryState.unknown:
            batteryState = AWSDKLocalization.getLocalizationString("UnknownTitle", "Unknown")
            
        case UIDeviceBatteryState.full:
            batteryState = AWSDKLocalization.getLocalizationString("UIDeviceBatteryStateFullMessage", "Full")
            
        case UIDeviceBatteryState.charging:
            batteryState = AWSDKLocalization.getLocalizationString("UIDeviceBatteryStateChargingMessage", "Charging")
            
        case UIDeviceBatteryState.unplugged:
            batteryState = AWSDKLocalization.getLocalizationString("UIDeviceBatteryStateUnpluggedMessage", "Unplugged")
        }
        
        return batteryState!
    }
}
