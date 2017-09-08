//
//  Sample.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import Foundation


public enum DataSampleType: UInt16, CustomStringConvertible, SwiftEnumSerializable {
    case dataUsage = 0
    case gps = 10
    case systemPower = 20
    case systemMemory = 21
    case systemInformation = 22
    case networkAdapterInformation = 40
    case analytics = 112

    public func data() throws -> Data {
        return dataFromInteger(self.rawValue)
    }

    public var description: String {
        switch self {
        case .dataUsage:
            return "DataSampleDataUsage"
        case .gps:
            return "DataSampleGPS"
        case .systemPower:
            return "DataSampleSystemPower"
        case .systemMemory:
            return "DataSampleSystemMemory"
        case .systemInformation:
            return "DataSampleSystemInformation"
        case .networkAdapterInformation:
            return "DataSampleNetworkAdapterInformation"
        case .analytics:
            return "DataSampleAnalytics"
        }
    }
}


extension DataSampleType: Hashable {
    public var hashValue: Int {
        return Int(self.rawValue)
    }
}

public func ==(x: DataSampleType, y: DataSampleType) -> Bool {
    return x.rawValue == y.rawValue
}


public protocol DataSample: SwiftStructSerializable {
    var sampleType: DataSampleType { get }
}


/**
    All DataSample payload struct should obey strictly the byte order and size when using
    `SwiftStructSerializable` to implicitly serialize the struct into NSData
 */
public struct BaseDataSample: DataSample {
    public var sampleType: DataSampleType {
        return self.messageId
    }

    let messageId: DataSampleType
    /// This might get overflow runtime error
    var messageSize: UInt16

    let year: UInt16
    let month: UInt16
    let day: UInt16
    let hour: UInt16
    let minute: UInt16
    let second: UInt16
    let millisecond: UInt16

    public init(type: DataSampleType) {
        self.messageId = type
        /// The constant size is used to guard against any modification of Sample struct
        self.messageSize = 18

        /// XXX: Use nanoseconds might be overkilling here
        var tp = mach_timespec(tv_sec: 0, tv_nsec: 0)
        var clk: clock_serv_t = 0
        host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &clk)
        clock_get_time(clk, &tp)
        mach_port_deallocate(mach_task_self_, clk)

        var tpsec = Int(tp.tv_sec)
        let tmval = gmtime(&tpsec).pointee

        /// XXX: Watch out for downcast from Int32 to UInt16
        self.day = UInt16(tmval.tm_mday)
        self.month = UInt16(tmval.tm_mon) + 1
        self.year = UInt16(tmval.tm_year) + 1900
        self.minute = UInt16(tmval.tm_min)
        self.hour = UInt16(tmval.tm_hour)
        self.second = UInt16(tmval.tm_sec)
        self.millisecond = UInt16(tp.tv_nsec / 1_000_000)
    }
}
