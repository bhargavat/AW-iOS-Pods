//
//  DataSamplerMemoryModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import Foundation

class DataSamplerMemoryModule: DataSamplerBaseModule{
    
    override func sample() throws -> [DataSample] {
        let totalPhysical = UIDevice.current.totalPhysicalMemory
        
        let availablePhysical = UInt32(calculateSize(HW_USERMEM))
        let totalPageFile = UInt32(calculateSize(HW_PAGESIZE))
        
        let memorySample: DataSample = DataSampleSystemMemory.init(totalPhysical: UInt32(totalPhysical), availablePhysical: availablePhysical, totalPageFile: totalPageFile)
        
        var sample = [DataSample]()
        sample.append(memorySample)
        return sample
    }
    
    func calculateSize(_ forHwIdentifier: Int32) -> UInt32
    {
        var mib: Array <Int32> = [CTL_HW, forHwIdentifier]
        let namelen : Int = MemoryLayout.size(ofValue: mib) / MemoryLayout.size(ofValue: mib[0])
        
        var len: Int = MemoryLayout<Int>.size
        
        var totalSize: UInt64 = 0
        
        let size: Int32 = sysctl(&mib, UInt32(namelen), &totalSize, &len, nil, 0)
        
        if (size < 0)
        {
            log(error: "AWError: Calculate Size returned invalid value")
            totalSize = 0
        }
        else if(totalSize > UInt64(UInt32.max))
        {
            totalSize = UInt64(UInt32.max)
        }
        
        return UInt32(totalSize)
    }
}
