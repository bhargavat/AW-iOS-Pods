//
//  DataSampleSystemInfo.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWHelpers
import Foundation

let  processorArchitectureARMv4: UInt16                 = 4

public enum ProcessorArchitecture: UInt16, SwiftEnumSerializable {
    case intel = 0
    case mips = 1
    case shx = 4
    case arm = 5
    case unknown = 0xFFFF
    
    public func data() throws -> Data {
        return dataFromInteger(self.rawValue)
    }
}


public enum ProcessorInstructionSet: UInt32, SwiftEnumSerializable {
    case floatingPoint = 1
    case dsp = 2
    case instruction16Bit = 4
    
    public func data() throws -> Data {
        return dataFromInteger(self.rawValue)
    }
}


public struct DataSampleSystemInfo: DataSample {
    var base: BaseDataSample

    let platformId: UInt32
    let osVersionMajor: UInt32
    let osVersionMinor: UInt32
    let osVersionPatch: UInt32

    let processorArch: UInt16
    let cpuLevel: UInt16
    let cpuRevision: UInt16

    let instructionSet: UInt32
    let oemInfoSize: UInt16

    let platformTypeSize: UInt16
    let platformType: NSData

    public var sampleType: DataSampleType {
        return .systemInformation
    }

    public init(platformId: UInt32 = 0, majorVer: UInt32 = 0, minorVer: UInt32 = 0, patchVer: UInt32 = 0,
                processorArch: UInt16 = processorArchitectureARMv4, cpuLevel: UInt16 = 0, cpuRevision: UInt16 = 0,
                instructionSet: UInt32 = 0, oemInfoSize: UInt16 = 0, platformType: NSData) {
        base = BaseDataSample(type: .systemInformation)

        self.platformId = platformId
        self.osVersionMajor = majorVer
        self.osVersionMinor = minorVer
        self.osVersionPatch = patchVer

        self.processorArch = processorArch
        self.cpuLevel = cpuLevel
        self.cpuRevision = cpuRevision

        self.instructionSet = instructionSet
        self.oemInfoSize = oemInfoSize

        self.platformType = platformType
        self.platformTypeSize = UInt16(self.platformType.length)

        if let data = try? self.data() {
            self.base.messageSize = UInt16(data.count)
        } else {
            self.base.messageSize = 0
        }
    }
}
