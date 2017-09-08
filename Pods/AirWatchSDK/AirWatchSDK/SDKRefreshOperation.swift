//
//  SDKSetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

class SDKRefreshOperation: SDKSetupAsyncOperation {

    override func startOperation() {

        let refreshSDKOperationsChain: [SDKOperation.Type] = [ SDKAccessControlSetupOperation.self,
                                                               SendBeaconOperation.self,
                                                               FetchConsoleCommandsOperation.self
                                                              ]
        let sdkRefreshOperations = self.createDependencyChain(refreshSDKOperationsChain, dataStore: self.dataStore)
        SDKOperationQueue.sharedQueue.addOperations(sdkRefreshOperations, waitUntilFinished: true)
        self.markOperationComplete()
    }
}
