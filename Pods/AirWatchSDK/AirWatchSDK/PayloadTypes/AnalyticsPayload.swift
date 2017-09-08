//
//  AnalyticsPayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 * @brief		Analytics payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the analtyics group of an SDK profile.
 * @version     6.0
 */
@objc(AWAnalyticsPayload)
public class AnalyticsPayload: ProfilePayload {
    public fileprivate (set) var enabled: Bool = false

    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        self.enabled ??= dictionary.bool(for: AnalyticsPayloadConstants.kAnalyticsPayloadEnabled)
    }

    override public class func payloadType() -> String {
        return AnalyticsPayloadConstants.kAnaltyicsPayloadType
    }
}
