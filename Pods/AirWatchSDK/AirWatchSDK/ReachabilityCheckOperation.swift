//
//  ReachabilityCheckOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWHelpers

internal class ReachabilityCheckOperation: SDKSetupAsyncOperation {
    internal var networkStatus: NetworkReachabilityStatus = .notReachable

    override func startOperation() {
        guard
            let hostname = self.dataStore.enrollmentInformation?.hostname,
            let reachability = Reachability(hostname: hostname)
        else {
            markOperationFailed()
            return
        }
        networkStatus = reachability.currentReachabilityStatus
        if networkStatus != .notReachable {
            markOperationComplete()
            return
        }
        
        AuthenticationServices.validateAuthenticationServicesAvailability(hostname) { [weak self] (validatedHostname, error) in
            if validatedHostname != nil {
                self?.networkStatus = .reachableViaWifi //?? how can we make sure that this would not affect users with celluar only access?
                self?.markOperationComplete()
            } else {
                self?.markOperationFailed()
            }
        }
    }

}
