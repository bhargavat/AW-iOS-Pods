//
//  IdentitySetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWError
import AWPresentation
import Foundation

internal class VerifyApplicationIdentityOperation: SDKSetupAsyncOperation {

    override internal func startOperation() {

        if self.dataStore.applicationIdentity?.authorization == nil {
            var sharedStore = "Shared Data Store"
            if let currentStore = self.dataStore as? ApplicationDataStore {
                sharedStore = currentStore.shared ? "Shared Data Store" : "Non Shared Data Store"
            }
            log(error: "Application Identity is missing from current Master Store. (\(sharedStore))")
            log(error: "Going to establish Appliction identity in (\(sharedStore))")
            let appIdentitySetupOperation = ApplicationIdentitySetupOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
            SDKOperationQueue.workerQueue.addOperations([appIdentitySetupOperation], waitUntilFinished: true)

            if (dataStore.applicationIdentity) != nil {
                log(info: "Established Application Identity with either user input/ from common identity.")
            }
        }
        
        guard self.dataStore.applicationIdentity?.authorization != nil else {
            log(error: "Failed to get app appIdentity marking operation failure")
            #if sdk_mixpanel_data_collection_enabled
                let initializationFailureError = AWError.SDK.Operation.VerifyApplicationIdentity.failedToGetApplicationIdentity
                SDKMixpanelDataCollectionService.sharedInstance?.track(event: SDKLifeCycleEvent.initialization(false, initializationFailureError.errorDescription))
            #endif

            self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.applicationIdentityNotSet)
            self.markOperationFailed()
            return
        }


        log(debug: "Application Identity is available from current Master Store.")
        self.markOperationComplete()
    }
}
