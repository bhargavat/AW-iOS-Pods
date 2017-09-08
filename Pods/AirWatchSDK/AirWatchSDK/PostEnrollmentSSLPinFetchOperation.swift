//
//  PostEnrollmentSSLPinFetch.swift
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

/// This covers pre-enrollment flow for fetching any SSL certs needed to complete Enrollment.
class PostEnrollmentSSLPinFetchOperation: SDKSetupAsyncOperation {

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }
    
    /// This is where the SSL Pin Fetch begins.
    override func startOperation() {
        guard let deviceServices = self.dataStore.deviceServices else {
            self.markOperationFailed()
            return
        }

        deviceServices.fetchCertificatesToPin{ [weak self] (pinningResponse: [String: [String]]?, error: NSError?) in

            if let publicKeysToPin = pinningResponse {

                if publicKeysToPin.count > 0 { /// There are Keys in the response
                    var sslTrustPublicKeys: [String: [String]] = [:]
                    for keyHost in publicKeysToPin.keys {
                        sslTrustPublicKeys[keyHost.lowercased()] = publicKeysToPin[keyHost]
                    }
                    self?.dataStore.SSLTrustPublicKeys = sslTrustPublicKeys
                } else { /// proper JSON response with no Keys
                    self?.dataStore.SSLTrustPublicKeys = nil
                }

                self?.markOperationComplete()
                return
            }

            if let error = error {
                log(error: "Post Enrollment SSL Pinning Fetch operation received error, \(error)")
            }
            self?.markOperationFailed()
        }
    }
}
