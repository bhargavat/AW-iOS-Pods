//
//  Abstct.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWServices

extension AbstractDataStoreItemLoader {


    func loadProfiles() -> [Profile] {
        let loadableProfileTypes: [AWSDK.ConfigurationProfileType] = [ .agent, .browser, .contentLocker, .sharedDevice, .sdk, .sdkAppWrapping, .boxer, .email ]
        var profiles: [Profile] = []
        for profileType in loadableProfileTypes {
            if let profile = self.loadProfile(profileType.StringValue) {
                profiles.append(profile)
            }
        }
        return profiles
    }

    func fetchProfile(_ profileType: String) -> Profile? {
        guard profileType != AWSDK.ConfigurationProfileType.unknown.StringValue else {
            log(error: "Error: Need a valid ConfigurationProfileType to return profile from store")
            return nil
        }

        guard let profileDictionary: NSDictionary = self.profilesStore.get(profileType) else {
            return nil
        }

        if let dictionary = profileDictionary as? [String: AnyObject] {
            return Profile(info: dictionary)
        }

        log(error: "Error: Failed to load profile from store: \(profileType)")
        return nil
    }

    mutating func storeProfile(_ profile: Profile) -> Bool {
        let profileType: AWSDK.ConfigurationProfileType = profile.profileType
        guard let dataValue: Data = profile.toData() else {
            log(error: "Error: Profile cannot be converted into data")
            return false
        }
        let profileTypeStr: String = profileType.StringValue
        return self.profilesStore.set(profileTypeStr, value: dataValue)
    }

    mutating func removeProfile(_ profileType: String) -> Bool {
        let profile: Data? = nil
        if self.profilesStore.set(profileType, value: profile) {
            log(info: "Profile was wiped successfully")
            return true
        }

        log(error: "Error: Failed To wipe profile Type\(profileType): to store")
        return false
    }

}
