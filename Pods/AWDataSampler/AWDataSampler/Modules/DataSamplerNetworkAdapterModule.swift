//
//  DataSamplerNetworkAdapterModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWHelpers

let DefaultIp = "0.0.0.0"

class DataSamplerNetworkAdapterModule: DataSamplerBaseModule {

    var networkAdapter = AWNetworkAdapter.init()
    var macAddress: String = ""
    var currentIPAddress: String = ""
    var networkSample: DataSampleNetworkAdapterInfo?
    
    init(inAdapter: AWNetworkAdapter)
    {
        networkAdapter = inAdapter
        if let value = networkAdapter.macAddress {
            macAddress = value
        }else {
            macAddress = "00:00:00:00:00:00"
        }
        
        if let value = networkAdapter.ipV4Address {
            currentIPAddress = value
        }else {
            currentIPAddress = DefaultIp
        }
    }
    
    override func sample() throws -> [DataSample] {
        
        var type: UInt32 = networkAdapter.isLoopback ? 24 : 0
        if (networkAdapter.name == "pdp_ip0") {
            type = 23
        }
        
        let adapterNameSize = UInt16(networkAdapter.name.lengthOfBytes(using: String.Encoding.utf8))
        
        let adapterDescriptionSize = UInt16(networkAdapter.description.lengthOfBytes(using: String.Encoding.utf8))
        
        let macAddressData = getMACAddressBytes()
        let currentIPAddressStream = getDataStream(currentIPAddress)
        let currentIPMaskStream = getDataStream(DefaultIp)
        let adapterDescription = networkAdapter.description
        var adapterName = ""
        if let value = networkAdapter.name {
            adapterName = value
        }
        var sample = [DataSample]()
        let value = DataSampleNetworkAdapterInfo.init(type: type, adapterNameSize: adapterNameSize, adapterDescriptionSize: adapterDescriptionSize, macAddressData: macAddressData, currentIPAddressStream: currentIPAddressStream, currentIPMaskStream: currentIPMaskStream, dhcpIPAdressStream: currentIPMaskStream, dhcpIPMaskStream: currentIPMaskStream, adapterName: adapterName, adapterDescription: adapterDescription, ipAddressStream: currentIPAddressStream, ipMaskStream: currentIPAddressStream)
        networkSample = value
        sample.append(value)
        return sample
    }
    
    func getMACAddressBytes() -> NSData {
        @inline(__always)
        func toHexInt(_ string: String) -> UInt32 {
            /// Default to 0
            var result: UInt32 = 0
            Scanner(string: string).scanHexInt32(&result)
            return result
        }

        let macAddress: String = self.macAddress
        var byteArray = [UInt8](repeating: 0, count: 8)
        
        if macAddress.characters.count == 17 {
            
            for index in 0...5{
                
                let startIndex = macAddress.characters.index(macAddress.startIndex, offsetBy: Int(3*index))
                let endIndex = macAddress.characters.index(startIndex, offsetBy: 1)
                let firstSubstr = macAddress.substring(with: startIndex..<endIndex)
                
                var first: UInt8 = UInt8(toHexInt(firstSubstr))
                first = first << 4
                
                let startIndexSecond = macAddress.characters.index(macAddress.startIndex, offsetBy: Int(3 * index + 1))

                let secondSubstr =  macAddress.substring(with: startIndexSecond..<endIndex)
                
                let second: UInt8 = UInt8(toHexInt(secondSubstr))
                let final: UInt8 = first + second

                byteArray[Int(index)] = final
            }
        }
        
        return NSMutableData(bytes: byteArray, length: MemoryLayout.size(ofValue: byteArray) / MemoryLayout<UInt8>.size)
    }
    
    func getDataStream(_ inStr: String) -> NSData{
        
        // Incase the inStr is "0.0.0.0" we need to pad to have a total of 15 bytes
        var currentStream = Data(count: 15)
        let lengthOfString = inStr.characters.count
        if lengthOfString < 16 {
            if let currentData: Data = inStr.data(using: String.Encoding.utf8)  {
                currentStream.replaceSubrange(0..<lengthOfString, with: currentData)
                return currentStream as NSData
            }
        }
        
        return Data(count: 15) as NSData
        
        
    }
}
