//
//  ProfileSettings.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 * @brief		A key-value pair for a profile group.
 * @details	Represents a key-value pair that is used in conjunction with a profile.
 */
@objc(AWProfileSetting)
public class ProfileSetting: NSObject {

    /** The name of the setting. */
    public fileprivate (set) var name: String

    /** The value of the setting. */
    public fileprivate (set) var settingValue: Any

    @objc(initWithDictionary:settingValue:)
    public init(name: String, settingValue: Any) {
        self.name = name
        self.settingValue = settingValue
    }
}
