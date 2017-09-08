//
//  DataSampleNetworkAdapterInfo.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers

public struct NetworkPlaceholder: SwiftStructSerializable {
    let year                : UInt16
    let month               : UInt16
    let day                 : UInt16
    let hour                : UInt16
    let minute              : UInt16
    let second              : UInt16
    let millisecond         : UInt16
    
    public init(year: UInt16 = 0, month: UInt16 = 0, day: UInt16 = 0, hour: UInt16 = 0, minute: UInt16 = 0, second: UInt16 = 0, millisecond: UInt16 = 0){
        self.year           = year
        self.month          = month
        self.day            = day
        self.hour           = hour
        self.minute         = minute
        self.second         = second
        self.millisecond    = millisecond
    }
}

public struct DataSampleNetworkAdapterInfo: DataSample {
    var base                    : BaseDataSample
    
    let type                    : UInt32
    let adapterNameSize         : UInt16
    let adapterDescriptionSize  : UInt16
    let ipAddressCount          : UInt16
    let gatewayCount            : UInt16
    let haveWINS                : UInt16
    
    let macAddressSize          : UInt16
    let macAddressData          : NSData
    let currentIPAddressStream  : NSData
    let currentIPMaskStream     : NSData
    let currentNTEContext       : UInt32
    
    let dhcpEnabled             : UInt16
    let dhcpIPAdressStream      : NSData
    let dhcpIPMaskStream        : NSData
    let dhcpNTEContext          : UInt32
    
    let placeholderSampleA      : NetworkPlaceholder
    let placeholderSampleB      : NetworkPlaceholder
    let adapterName             : String
    let adapterDescription      : String
    let ipAddressStream         : NSData
    let ipMaskStream            : NSData
    let currentContextNTE       : UInt32
    
    public var sampleType: DataSampleType {
        return .networkAdapterInformation
    }
    
    public init(type: UInt32 = 0, adapterNameSize: UInt16 = 0, adapterDescriptionSize:UInt16  = 0, ipAddressCount: UInt16 = 0, gatewayCount: UInt16 = 0, haveWINS:UInt16 = 0, macAddressSize: UInt16 = 0, macAddressData: NSData, currentIPAddressStream: NSData, currentIPMaskStream: NSData,currentNTEContext: UInt32 = 0, dhcpEnabled: UInt16 = 0, dhcpIPAdressStream: NSData, dhcpIPMaskStream: NSData, dhcpNTEContext: UInt32 = 0, placeholderSampleA: NetworkPlaceholder = NetworkPlaceholder(), placeholderSampleB: NetworkPlaceholder = NetworkPlaceholder(), adapterName: String = "", adapterDescription: String = "", ipAddressStream: NSData, ipMaskStream: NSData,currentContextNTE: UInt32 = 0) {

        base = BaseDataSample(type: .networkAdapterInformation)

        self.type = type
        self.adapterNameSize = adapterNameSize
        self.adapterDescriptionSize = adapterDescriptionSize
        self.ipAddressCount = ipAddressCount
        self.gatewayCount = gatewayCount
        self.haveWINS = haveWINS

        self.macAddressSize = macAddressSize
        self.macAddressData = macAddressData
        self.currentIPAddressStream = currentIPAddressStream
        self.currentIPMaskStream = currentIPMaskStream
        self.currentNTEContext = currentNTEContext

        self.dhcpEnabled = dhcpEnabled
        self.dhcpIPAdressStream = dhcpIPAdressStream
        self.dhcpIPMaskStream = dhcpIPMaskStream
        self.dhcpNTEContext = dhcpNTEContext

        self.placeholderSampleA = placeholderSampleA
        self.placeholderSampleB = placeholderSampleB
        self.adapterName = adapterName
        self.adapterDescription = adapterDescription
        self.ipAddressStream = ipAddressStream
        self.ipMaskStream = ipMaskStream
        self.currentContextNTE = currentContextNTE

        if let data = try? self.data() {
            self.base.messageSize = UInt16(data.count)
        } else {
            self.base.messageSize = 0
        }
    }
}
