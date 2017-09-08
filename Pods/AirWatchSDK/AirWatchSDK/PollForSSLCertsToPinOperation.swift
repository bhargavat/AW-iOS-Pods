//
//  PollForSSLCertsToPin.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWNetwork
import AWCrypto

extension Integer {
    var secondsFromDays: Self {
        return 60 /*seconds per minute*/ * 60 /*minutes per hour*/ * 24 /*hours per day*/ * self
    }

    var secondsFromHours: Self {
        return 60 /*seconds per minute*/ * 60 /*minutes per hour*/ * self
    }
    var secondsFromMinutes: Self {
        return 60 /*seconds per minute*/ * self
    }

}

/// This covers post-enrollment flow for fetching any updated SSL certs to pin from Device Services.
/// The reason for this only happening post-enrollment is because of the need for security authorization to communicate with the required endpoint.
class PollForSSLCertsToPinOperation: SDKSetupAsyncOperation {
    var networkService: CTLService = CTLService()

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }

    /// This is where the SSL Pin Fetch begins.
    override func startOperation() {
        
        #if CERTIFICATE_PINNING
            let store = self.dataStore
            let lastCertFetchTime = store.timeOfLastSSLTrustKeyFetch
            
            var timeSinceLastFetch: TimeInterval = Double(2.secondsFromDays)
            
            // if we have a previously stored time for last fetch, use it, else trigger a new fetch.
            if let storedTimeSinceLastFetch = lastCertFetchTime?.timeIntervalSinceNow {
                timeSinceLastFetch = -1 * storedTimeSinceLastFetch
            }
            
            if timeSinceLastFetch >= Double(1.secondsFromDays) {
                /// timeSinceLastFetch is greater than or equal to a day
                let fetchOp = PostEnrollmentSSLPinFetchOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
                
                fetchOp.completionBlock = {[weak self, weak fetchOp] in
                    guard let weakSelf = self, let operation = fetchOp else {
                        return
                    }


                    if operation.operationCompletedSuccessfully {
                        /// Replace currently stored keys with newly fetched keys...Even if they are nil.
                        weakSelf.dataStore.SSLTrustPublicKeys = operation.dataStore.SSLTrustPublicKeys
                        CTLSessionFetcher.resetSessionManager()
                        weakSelf.dataStore.timeOfLastSSLTrustKeyFetch = Date()
                        weakSelf.sdkController.authHandler.setupServerTrustHandling()
                        log(info: "Successfully updated pinned certificates from device services.")
                        weakSelf.markOperationComplete()
                        return
                    }
                    // The operation to update the pinned certs was not successful, so no need to update the timestamp.
                    log(error: "Failed to update pinned certificates from device services.")
                    
                    // Marking operation as complete so as to not block dependent operations.
                    weakSelf.markOperationComplete()
                }
                
                // Setting up initial set of pinned certs from Autodiscovery/TrustService
                // if no pinned certs previously saved to device.
                // This should cover upgrade scenarios where user was enrolled before admin set Cert Pinning.
                if self.dataStore.SSLTrustPublicKeys == nil || self.dataStore.SSLTrustPublicKeys?.count == 0 {
                    
                    let prefetchOp = PinningCertificateFetchOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
                    
                    fetchOp.addDependency(prefetchOp)
                    
                    SDKOperationQueue.workerQueue.addOperation(prefetchOp)
                }
                
                /// Add fetchOp to a queue to run.
                SDKOperationQueue.workerQueue.addOperation(fetchOp)
                
            } else {
                /// timeSinceLastFetch is less than a day, so no need to fetch new certs.
                self.markOperationComplete()
            }
        #else
            /// Certificate Pinning has been disabled at the build level.
            /// Clearing any previously pinned keys/certs and continuing forward.
            self.dataStore.SSLTrustPublicKeys = nil
            CTLSessionFetcher.resetSessionManager()
            self.markOperationComplete()
            return
        #endif
    }
}
