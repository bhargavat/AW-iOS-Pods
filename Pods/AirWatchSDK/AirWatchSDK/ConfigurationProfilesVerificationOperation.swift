//
//  ConfigurationProfileVerificationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWError

class ConfigurationProfilesVerificationOperation: SDKSetupAsyncOperation {

    struct ProfilesStorage: ProfileStoreHandler {
        var profileStorage: SDKContext
    }

    override func startOperation() {
        let profileTypesToLoad = self.sdkController.requestingProfiles.filter { $0 != AWSDK.ConfigurationProfileType.unknown.StringValue }

        let profiles = self.loadProfileFromStore(profileTypesToLoad)
        
        if profileTypesToLoad.count == profiles.count {
            log(debug: "All profiled required by the Application and SDK are present.")
            log(info: "We will check for any updates to the profile later in the flow.")
        }
        
        log(debug: "Required Profiles: \(profileTypesToLoad.count). Loaded from Store: \(profiles.count)")
        let fetchOpearation = ConfigurationProfilesSetupOperation(sdkController: self.sdkController,
                                                                 presenter: self.presenter,
                                                                 dataStore: self.dataStore)
        
        fetchOpearation.completionBlock = { [weak fetchOpearation, weak self] in
            guard let fetchOpearation = fetchOpearation,
                let weakSelf = self else {
                return
            }
            
            guard fetchOpearation.operationCompletedSuccessfully else {
                log(error: "Failed to finish setting up configuration profiles. Will have to stop SDK setup and throw an error")
                weakSelf.markOperationFailed()

                #if sdk_mixpanel_data_collection_enabled
                    let event = SDKLifeCycleEvent.initialization(false, AWSDKError.Profile.Retriever.failedToFetchProfile.errorDescription)
                    SDKMixpanelDataCollectionService.sharedInstance?.track(event: event)
                #endif

                return
            }
            
            log(info: "Required Configuration profiles are available to move forward.")
            self?.markOperationComplete()
        }

        SDKOperationQueue.workerQueue.addOperation(fetchOpearation)
    }

    fileprivate func loadProfileFromStore(_ profileTypes: [String]) -> [Profile] {
        var profiles: [Profile] = []
        let profileStore = ProfilesStorage(profileStorage: self.dataStore)
        profileTypes.forEach({ (profileType) in
            if let profile = profileStore.loadProfileFromStore(profileType) {
                profiles.append(profile)
            }
        })
        return profiles
    }
}
