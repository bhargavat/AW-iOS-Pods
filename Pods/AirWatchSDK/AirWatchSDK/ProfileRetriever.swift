//
//  ProfileRetriever.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWError

typealias ProfileRetrieverCompletionHandler = (_ success: Bool, _ profile: Profile?, _ error: Error?) -> Void

internal protocol ProfileRetrieverProtocol {
    var deviceServices: DeviceServices? { get }
    func fetchConfigurationProfile(type: AWSDK.ConfigurationProfileType, completionHandler: @escaping ProfileRetrieverCompletionHandler)
}

extension ProfileRetrieverProtocol {

    func fetchConfigurationProfile(type: AWSDK.ConfigurationProfileType, completionHandler: @escaping ProfileRetrieverCompletionHandler) {
        guard let deviceServices = deviceServices else {
            log(error: "Error: Failed to fetch profile \(String(reflecting: type)) with empty device services")
            let err = NSError(domain: "Profile Retrieval Error", code: -1, userInfo: nil)//incase of both profile and error == nil
            completionHandler(false, nil, err)
            return
        }
        
        let fetchProfilesCompletionHandler: FetchProfileCompletion = {(profileData: Data?, error: NSError?) in
            if let error = error {
                completionHandler(false, nil, error)
            }

            guard
                let profileData = profileData,
                let profile = Profile(profileData: profileData, profileType: type)
            else {
                    log(error: "Error: Failed to successfully fetch configuration profile error:\(String(describing: error))")
                    completionHandler(false, nil, AWError.SDK.Service.General.unexpectedResponse.error)
                    return
            }

            completionHandler(true, profile, error)
        }
        deviceServices.fetchConfigurationProfile(type: type.servicesProfileType, completionHandler: fetchProfilesCompletionHandler)
    }
}

struct ProfileRetriever: ProfileRetrieverProtocol {
    var deviceServices: DeviceServices?
}
