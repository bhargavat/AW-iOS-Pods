//
//  DiscoverTrustServiceOperation.swift
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

class DiscoverTrustServiceOperation: SDKSetupAsyncOperation {
    
    var networkService: CTLService = CTLService()
    
    var trustService: String? = nil
    var error: NSError? = nil
    
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }
    
    override func startOperation() {
        guard let awHost = dataStore.consoleServicesConfig?.airWatchServerURL else {
            log(error: "Can't retrieve Any SSL Pinning services when no Host exists")
            completeOperation(AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }

        let trustServices = TrustServices(serverURL: awHost)
        trustServices.retrieveTrustServiceURL { (trustServiceUrlString, error) in

            if let discoveredTrustService = trustServiceUrlString {
                self.trustService = discoveredTrustService
                self.completeOperation()
                return
            }
            
            if let error = error {
                self.completeOperation(error as NSError?)
            } else {
                self.completeOperation(AWError.SDK.CertificatePinning.failedToFetchPinningCertificate.error)
            }
        }
        
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
