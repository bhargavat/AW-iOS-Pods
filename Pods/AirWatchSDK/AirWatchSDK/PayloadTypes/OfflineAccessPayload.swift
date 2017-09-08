//
//  OfflineAccessPayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 * @brief       OfflineAccessPayload payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the Offline Access group of an SDK profile.
 * @version     6.0
 */
@objc(AWOfflineAccessPayload)
public class OfflineAccessPayload: ProfilePayload {
    public fileprivate (set) var enableOfflineAccess: Bool = true
    public fileprivate (set) var maximumSecondsAllowedOffline: TimeInterval = -1

    /// For constructing this payload in UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        self.enableOfflineAccess ??= dictionary.bool(for: OfflineAccessPayloadConstants.kAWOfflineAccessEnabledKey)
        if let doubleValue = dictionary.double(for: OfflineAccessPayloadConstants.kAWOfflineMaximumPeriodAllowedKey) {
            self.maximumSecondsAllowedOffline = TimeInterval(doubleValue) 
        }
    }

    override public class func payloadType() -> String {
        return OfflineAccessPayloadConstants.kAWOfflineAccessPayloadType
    }
}
