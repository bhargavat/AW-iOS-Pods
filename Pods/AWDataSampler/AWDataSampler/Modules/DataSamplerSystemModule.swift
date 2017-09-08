//
//  DataSamplerSystemModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWHelpers
import Foundation


class DataSamplerSystemModule: DataSamplerBaseModule {
    
    override func sample() throws -> [DataSample]
    {
        let currentDevice = UIDevice.current
        
        if let systemName = currentDevice.systemName.data(using: String.Encoding.utf16) {
            let offsetValue = 2
            let platformType = systemName.subdata(in: offsetValue..<systemName.count) as NSData
            let OSVersion = currentDevice.operatingSystemVersion()
            let systemSample: DataSample = DataSampleSystemInfo.init(platformId: UInt32(currentDevice.deviceTypeIdentifier), majorVer: UInt32(OSVersion.0), minorVer: UInt32(OSVersion.1), patchVer: UInt32(OSVersion.2), platformType: platformType)
            
            var sample = [DataSample]()
            sample.append(systemSample)
            return sample
        }
        return []
    }
}
