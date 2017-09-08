//
//  DataSampleMemory.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public struct DataSampleSystemMemory: DataSample {

    var base: BaseDataSample

    let memoryLoad: UInt32
    let totalPhysical: UInt32
    let availablePhysical: UInt32
    let totalPageFile: UInt32
    let availablePageFile: UInt32
    let totalVirtual: UInt32
    let availableVirtual: UInt32

    public var sampleType: DataSampleType {
        return .systemMemory
    }

    public init(memoryLoad: UInt32 = 0, totalPhysical: UInt32 = 0, availablePhysical: UInt32 = 0, totalPageFile: UInt32 = 0,
                availablePageFile: UInt32 = 0, totalVirtual: UInt32 = 0, availableVirtual: UInt32 = 0) {
        
        base = BaseDataSample(type: .systemMemory)

        self.memoryLoad = memoryLoad
        self.totalPhysical = totalPhysical
        self.availablePhysical = availablePhysical
        self.totalPageFile = totalPageFile
        self.availablePageFile = availablePageFile
        self.totalVirtual = totalVirtual
        self.availableVirtual = availableVirtual

        if let data = try? self.data() {
            self.base.messageSize = UInt16(data.count)
        } else {
            self.base.messageSize = 0
        }
    }
}
