//
//  DataSamplerPowerModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

class DataSamplerPowerModule: DataSamplerBaseModule {
    
    override func sample() throws -> [DataSample]
    {
        let device = UIDevice.current
        let powerLineStatus = device.powerLineType()
        let batteryStatus = UInt8(device.batteryState.rawValue)
        let batteryLife = device.batteryLifePercent()
        //let BatteryLifeTime = device.batteryLifeTime()
        
        let powerSample: DataSample = DataSampleSystemPower.init(powerLineStatus: powerLineStatus, batteryStatus: batteryStatus, batteryLifePercent: batteryLife)
        
        var sample = [DataSample]()
        sample.append(powerSample)
        return sample
    }
}
