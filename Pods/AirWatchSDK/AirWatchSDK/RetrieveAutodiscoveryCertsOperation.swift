//
//  RetrieveAutodiscoveryCertsOperation.swift
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
import AWError

class RetrieveAutodiscoveryCertsOperation: SDKSetupAsyncOperation {
    
    var deviceServices: DeviceServices?
    var networkService: CTLService = CTLService()
    var canReachAutoDiscovery: Bool = true
    var error: NSError? = nil
        
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        self.deviceServices = dataStore.deviceServices
    }
    
    override func startOperation() {

        guard let awUrlString = dataStore.enrollmentInformation?.hostname else {
            log(error: "Can't retrieve SSL public keys when there is no AirWatch Host to retrieve them for/from")
            completeOperation(NSError(domain: "PinningCertificateFetchOpeartion", code: 1, userInfo: nil))
            return
        }
        guard let awHost = NSURL(string: awUrlString)?.host else {
            log(error: "Can't retrieve SSL public keys when there is no AirWatch Host to retrieve them for/from")
            completeOperation(NSError(domain: "PinningCertificateFetchOpeartion", code: 1, userInfo: nil))
            return
        }
        #if DEBUG
            let autoDiscovery = AutoDiscoveryService(AutoDiscoveryHost: "qa17.airwatchqa.com")
        #else
            let autoDiscovery = AutoDiscoveryService(AutoDiscoveryHost: "discovery.awmdm.com")
        #endif
        
        guard let config = dataStore.deviceServices?.config else {
            log(error: "Can't retrieve SSL public keys when there is no AirWatch Host to retrieve them for/from")
            completeOperation(NSError(domain: "PinningCertificateFetchOpeartion", code: 1, userInfo: nil))
            return
        }
        
        /// Try requesting Public SSL Keys to pin from AutoDiscovery
        autoDiscovery?.requestSSLPin(forAirWatchHost: awHost, withConfiguration: config, completionHandler: {[unowned self] (response: SSLPinResponseObject?, error: NSError?) in
            /// This conditional should fail if the response object is nil, as well as when the response object is empty
            if let publicKeys = response, (response?.host.characters.count)! > 0 {
                /// Store the publicKeys that were retrieved to be used in SSL Pinning...
                
                self.dataStore.SSLTrustPublicKeys = [publicKeys.host.lowercased() : publicKeys.publicKeys]
                
                /// Complete the operation with success
                self.completeOperation()
                return
            } else if let error = error {
                log(error: "While trying to contact Auto Discovery Service for SSL Pinning, Received Error: \(error).")
                /// If there was an error, then could not reach AutoDiscovery, so set that bool for later use.
                self.canReachAutoDiscovery = false
            } else {
                log(debug: "AutoDiscovery didn't respond with any keys to pin")
                self.dataStore.SSLTrustPublicKeys = nil
            }
            /// Try to get the trust service to see if any Public SSL Keys are pinned there
            self.completeOperation(AWError.SDK.CertificatePinning.failedToFetchPinningCertificate.error)
        })
    }
    
    func completeOperation(_ error: NSError? = nil) {
        
        AWController.sharedInstance.authHandler = URLChallengeController(context: self.dataStore)
        
        if let error = error {
            log(error: "Pinning Certificate Fetch encountered Error: \(error)")
            self.error = error
            self.markOperationFailed()
        } else {
            /// Resets the Network Manager, thus resetting the server Trust to allow for validation against new pins.
            CTLSessionFetcher.resetSessionManager()
            self.markOperationComplete()
        }
    }
}
