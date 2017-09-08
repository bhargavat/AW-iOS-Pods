//
//  ProfileStoreHandler.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWServices
import AWServices

/*
 * @protocol ProfileStoreHandler is an internal protocol, responsible for all of the ProfileManager's interactions with storage.
 */
protocol ProfileStoreHandler {
    var profileStorage: SDKContext { get set }

    /*
     * @method      saveProfileToStore
     * @abstract    Use this method to save the given profile types to storage
     * @param       profile: The profile to be saved
     * @return      Returns a success value as a bool
     */
    mutating func saveProfileToStore(_ profile: Profile) -> Bool

    /*
     * @method      loadProfileFromStore
     * @abstract    Use this method to load a profile types from storage
     * @param       profileType: a string corresponding to the profile to be saved
     * @return      returns a profile if the desired profile was found in storage, otherwise returns nil
     */
    func loadProfileFromStore(_ profileType: String) -> Profile?
}


extension ProfileStoreHandler {

    mutating func saveProfileToStore(_ profile: Profile) -> Bool {
        return profileStorage.saveProfile(profile)
    }

    func loadProfileFromStore(_ profileType: String) -> Profile? {
        return profileStorage.loadProfile(profileType)
    }
}
