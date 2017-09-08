//
//  RetrieveTrustServiceCertsOperation.swift
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

class RetrieveTrustServiceCertsOperation: SDKSetupAsyncOperation {
    
    var deviceServices: DeviceServices?
    var networkService: CTLService = CTLService()
    
    var trustService: String? = nil
    var error: NSError? = nil
    
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        self.deviceServices = dataStore.deviceServices
    }
    
    override func startOperation() {
        
        guard let trustService = trustService else {
            self.completeOperation(AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        guard let awServer = dataStore.consoleServicesConfig?.airWatchServerURL else {
            self.completeOperation(AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        guard let awHost = NSURL(string: awServer)?.host else {
            log(error: "Can't retrieve SSL public keys when there is no AirWatch Host to retrieve them for/from")
            completeOperation(AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        /**
         SAMPLE REQUEST
         https://architecture.airwatchqa.com/TrustService/SSLPinning/Settings?URL=dev16.airwatchdev.com
         
         SAMPLE RESPONSE
         {
         "dev16.airwatchdev.com":[      "308189028181009A2B32357B32C12964D77DD80981E6FFEC0C483C95D76A00FA0F7A9B1E73837EC91FDC8B25C5D0D304E6C213C5F298D354E1D801DB22E1C9D93E7FDAD1AFCEE962016F1796DF05C42E29EA6A4E8A2035E87E6C69362C90B208960140A6B85FF051A2459F5EB559A487AC55D7167FC0448CE088B141DA7199A454D146BDEAF8C90203010001"
         ]
         }
         */
        
        guard let configuration = dataStore.deviceServices?.config else {
            completeOperation(AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        let endpoint = TrustServiceEndpoint(trustServiceUrl: trustService, withConfiguration: configuration)
        
        endpoint?.fetchPinnedCertsFromTrustService(forHost: awHost, completionHandler: { (response, error) in
            
            if let jsonDictionary = response {
                /// Use the public keys in the jsonDictionary to set the pinnedKeys Security Policy and continue enrollment
                
                var store = self.dataStore
                store.SSLTrustPublicKeys = jsonDictionary
                log(info: "Received response from Trust Service. Completing SSL Pin fetch.")
                self.completeOperation()
                return
            }
            
            log(info: "Could not reach Trust Service. Failing Enrollment Flow.")
            let outError: NSError?
            if let error = error {
                outError = error
            } else {
                outError = AWError.SDK.CertificatePinning.failedToFetchPinningCertificate.error
            }
            /// Was not able to reach AutoDiscovery, this means we must fail enrollment
            self.completeOperation(outError)
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
