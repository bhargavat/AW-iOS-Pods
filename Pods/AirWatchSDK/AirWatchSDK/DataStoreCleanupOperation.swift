//
//  DataStoreCleanupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWLocalization
import AWPresentation
import Foundation

/**
 Wipe all data in regards to the SDK and restart the SDK
 If you would like an alert message displayed when wipe has completed initialize an AlertReason object. You have to pass a message and it is not required to have a title.
 */
class DataStoreCleanupOperation: SDKSetupInlineOperation {

    override func startOperation() {
        //Cleanup Shared KeyChain Data.
        //Cleanup Non-shared KeyChain Data.
        //Cleanup Certificate Data
        if AWAnchor.isCurrentApplicationAirWatchApplication {
            log(error: "Wiping Application Data")
            self.dataStore.wipeApplicationData()
        }
        else {
            self.dataStore.wipeThirdPartyApplicationData()
            self.sdkController.resetOpenURLClient()
        }

        log(error: "Wiping all existing profiles")
        _ = self.dataStore.wipeAllProfiles()
        log(error: "Sending delegate\(String(describing: self.sdkController.delegate)) controllerDidWipeCurrentUserData")
        DispatchQueue.main.async {
            self.sdkController.delegate?.controllerDidWipeCurrentUserData?()
        }

        //reset dataStore
        log(error: "Reset Data Store.")
        let dataStore = ApplicationDataStore()
        AWController.sharedInstance.context = dataStore
        let sdkContextInfo = [NotificationObjectKeys.SDKContext.rawValue : dataStore]
        NotificationCenter.default.post(name: NSNotification.Name.sdkContextDidChange, object: nil,
                                        userInfo: sdkContextInfo)
        
        self.markOperationComplete()
        
    }
}
