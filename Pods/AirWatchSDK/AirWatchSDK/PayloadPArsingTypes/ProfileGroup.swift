//
//  ProfileGroup.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
/**
 @brief		Describes a profile group within a configuration profile.
 @details	A profile group is an app payload contained within a configuration profile.
 */
@objc(AWProfileGroup)
public class ProfileGroup: NSObject {

    /** The display name of the profile group. */
    public fileprivate (set) var displayName: String?

    /** The description of the profile group. */
    public fileprivate (set) var comments: String?

    /** The identifier of the profile group. */
    public fileprivate (set) var identifier: String?

    /** The organization of the profile group. */
    public fileprivate (set) var organization: String?

    /** The type of the profile group. */
    public fileprivate (set) var type: String?

    /** The UUID of the profile group. */
    public fileprivate (set) var uuid: String?

    /** The version of the profile group. */
    public fileprivate (set) var version: Int?

    /** The settings of the profile group. */
    public fileprivate (set) var settings: [ProfileSetting]

    /**
     * Returns a configuration profile built from a dictionary.
     * @param info The dictionary to be used to build the profile group.
     * @return Returns initialized profile group object.
     */
    @objc(initWithDictionary:)
    public init(info: [String: Any]) {
        self.settings = []
        var mutableCopy: [String: Any] = info

        // Set payload information
        displayName = info[ProfileGroupConstants.kPayloadDisplayName] as? String
        comments = info[ProfileGroupConstants.kPayloadDescription] as? String

        identifier = info[ProfileGroupConstants.kPayloadIdentifier] as? String
        organization = info[ProfileGroupConstants.kPayloadOrganization] as? String
        type = info[ProfileGroupConstants.kPayloadType] as? String
        uuid = info[ProfileGroupConstants.kPayloadUUID] as? String
        if let versionStr = info[ProfileGroupConstants.kPayloadVersion] as? String {
            version = Int(versionStr)
        }

        // Remove used keys from mutable dictionary
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadDisplayName)
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadDescription)
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadIdentifier)
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadOrganization)
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadType)
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadUUID)
        mutableCopy.removeValue(forKey: ProfileGroupConstants.kPayloadVersion)

        // Set payload settings
        for (key, value) in mutableCopy {
            // Create profile setting
            let setting: ProfileSetting = ProfileSetting(name: key, settingValue: value)
            settings.append(setting)
        }
    }


    @objc public func toDictionary() -> [String: Any] {
        var retDictionary: [String: Any] = [:]
        for profileSetting: ProfileSetting in settings {
            retDictionary[profileSetting.name] = profileSetting.settingValue
        }
        return retDictionary
    }
}
