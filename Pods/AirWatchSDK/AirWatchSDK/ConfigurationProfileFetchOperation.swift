//
//  FetchConfigurationProfileOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

class ConfigurationProfileFetchOperation: SDKSetupAsyncOperation, ProfileRetrieverProtocol {
    var fetchingProfileType = AWSDK.ConfigurationProfileType.sdk
    var fetchedProfile: Profile? = nil
    var deviceServices: DeviceServices? = nil
    
    convenience init(profile: AWSDK.ConfigurationProfileType, operation: SDKSetupAsyncOperation) {
        self.init(sdkController: operation.sdkController,
                  presenter: operation.presenter,
                  dataStore: operation.dataStore)
        self.name = "ConfigurationProfileFetchOperation: \(profile.StringValue)"
        self.deviceServices = dataStore.deviceServices
        self.fetchingProfileType = profile
    }
    
    override func startOperation() {
        log(debug: "Will Start Fetching \(fetchingProfileType.StringValue)")
        self.fetchConfigurationProfile(type: fetchingProfileType) { [weak self] (success: Bool, profile: Profile?, error: Error?) in
            
            guard
                let profile = profile,
                success == true,
                error == nil,
                let weakSelf = self
            else {
                log(error: "Profile fetch was not successful for profile Type: \(self?.fetchingProfileType.StringValue ?? "no type")")
                log(error: "Error Retrieving Profile Type: \(self?.fetchingProfileType.StringValue ?? "no type"), Error: \(String(describing:error))")
                self?.markOperationFailed()
                return
            }
            
            log(debug: "Saving Retrieved Profile \(weakSelf.fetchingProfileType.StringValue) To Store")
            weakSelf.fetchedProfile = profile
            _ = weakSelf.dataStore.saveProfile(profile)
            weakSelf.markOperationComplete()
        }
    }
}
