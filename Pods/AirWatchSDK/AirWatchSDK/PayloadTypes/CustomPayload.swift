//
//  CustomPayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 @brief     Custom payload that is contained within a 'AWProfile'.
 @version   6.0
 */
@objc(AWCustomPayload)
public class CustomPayload: ProfilePayload {
    public fileprivate(set) var settings: String?

    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        self.settings = dictionary[CustomPayloadConstants.kCustomSettingsKey] as? String
    }

    override public class func payloadType() -> String {
        return CustomPayloadConstants.kCustomPayloadType
    }
}
