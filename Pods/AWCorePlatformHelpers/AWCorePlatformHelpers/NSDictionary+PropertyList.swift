//
//  NSDictionary+PropertyList.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWError

extension NSDictionary {
    @objc
    public func xmlPlistData() throws -> Data {
        return try PropertyListSerialization.data(fromPropertyList: self,
                                                                    format: .xml,
                                                                    options: PropertyListSerialization.WriteOptions(0))
    }

    @objc
    public class func dictionaryFromPlistData(_ plistData: Data) throws -> NSDictionary {
        let dict = try PropertyListSerialization.propertyList(from: plistData,
                                                                         options: PropertyListSerialization.ReadOptions(rawValue: 0),
                                                                         format: nil)
        if let resultDict = dict as? NSDictionary {
            return resultDict
        }
        
        throw AWError.SDK.General.Conversion.FromData.propertyListSerializationFailed
    }
}
