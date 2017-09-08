//
//  PinningCertificateFetchOperation.swift
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

/// This covers pre-enrollment flow for fetching any SSL certs needed to complete Enrollment.
/// The diagram describing this flow can be found: https://confluence.air-watch.com/display/ARCH/SSL+Pinning
class PinningCertificateFetchOperation: SDKSetupAsyncOperation {

    var networkService: CTLService = CTLService()
    
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }
    
    /// This is where the SSL Pin Fetch begins.
    override func startOperation() {
        
        #if CERTIFICATE_PINNING
            var trustService: String? = nil
            var didReachAutoDiscovery:Bool = true
            
            let workingQueue = OperationQueue()
            
            /// First phase is to try to get pinned certs from AutoDiscovery
            let autoDiscoveryOp = RetrieveAutodiscoveryCertsOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
            workingQueue.addOperations([autoDiscoveryOp], waitUntilFinished: true)
            if autoDiscoveryOp.operationCompletedSuccessfully {
                completeOperation()
                return
            } else {
                didReachAutoDiscovery = autoDiscoveryOp.canReachAutoDiscovery
            }
            
            /// If first phase failed to retrieve pinned certs (for whatever reason), talk to DS about getting Trust Service URL.
            let trustServiceDiscoveryOp = DiscoverTrustServiceOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
            workingQueue.addOperations([trustServiceDiscoveryOp], waitUntilFinished: true)
            if trustServiceDiscoveryOp.operationCompletedSuccessfully {
                if let returnedUrl = trustServiceDiscoveryOp.trustService {
                    trustService = returnedUrl
                } else {
                    if didReachAutoDiscovery {
                        completeOperation()
                        return
                    }
                    completeOperation(AWError.SDK.CertificatePinning.failedToFetchPinningCertificate)
                    return
                }
            } else {
                if didReachAutoDiscovery {
                    completeOperation()
                    return
                }
            }
            
            guard let discoveredTrustService = trustService else {
                completeOperation(AWError.SDK.CertificatePinning.failedToFetchPinningCertificate)
                return
            }
            
            /// Final phase is to try to retrieve pinned certs from the given Trust Service.
            let fetchPinnedCertsFromTrustServiceOp = RetrieveTrustServiceCertsOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
            fetchPinnedCertsFromTrustServiceOp.trustService = discoveredTrustService
            workingQueue.addOperations([fetchPinnedCertsFromTrustServiceOp], waitUntilFinished: true)
            if fetchPinnedCertsFromTrustServiceOp.operationCompletedSuccessfully {
                completeOperation()
                return
            } else {
                completeOperation(AWError.SDK.CertificatePinning.failedToFetchPinningCertificate)
            }
            
        #else
            self.dataStore.SSLTrustPublicKeys = nil
            completeOperation()
            return
        #endif
    }
    
    func completeOperation(_ error: AWSDKErrorType? = nil) {
        
        AWController.sharedInstance.authHandler.setupServerTrustHandling()
        
        if let error = error {
            /// Was never able to reach a trusted source about getting certs to pin. Failing the operation.
            log(error: "Pinning Certificate Fetch encountered Error: \(error)")
            // MARK: Soft-fail is currently allowing a failed operation to complete successfully
            // TODO: when Soft-fail is disabled, change this back to "self.markOperationFailed()"
            
            self.markOperationComplete()
        } else {
            /// Resets the Network Manager, thus resetting the server Trust to allow for validation against new pins.
            CTLSessionFetcher.resetSessionManager()
            self.markOperationComplete()
        }
    }
    
}

