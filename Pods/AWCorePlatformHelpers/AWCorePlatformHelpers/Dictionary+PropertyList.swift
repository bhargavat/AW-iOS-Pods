//
//  Dictionary+PropertyList.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension Dictionary {

    /* Create dictionary from property list received from AirWatch Server */
    //    @objc(AW_dictionaryFromPropertyListData:error:)
    public static func dictionaryFromPropertyListData(_ plistData: Data) throws -> Dictionary {
        return try PropertyListSerialization.propertyList(from: plistData,
                                                                    options: PropertyListSerialization.ReadOptions(rawValue: 0),
                                                                    format: nil) as! Dictionary
    }
    
    public func propertyListDataFromDictionary() throws -> Data {
        return try PropertyListSerialization.data(fromPropertyList: self as AnyObject, format: PropertyListSerialization.PropertyListFormat.binary, options: 0)
    }
}
