//
//  CurrentUserLogoutOperation.swift
//  AirWatchSDK
//
//  Created by Anuj Panwar on 3/8/17.
//  Copyright © 2017 VMWare, Inc. All rights reserved.
//

import Foundation

class CurrentUserLogoutOperation: SDKSetupAsyncOperation {
    
    override func startOperation() {
        log(error: "Will be Cleaning up Data Store and Reporting Unenrollment to the Server")
        let operations = self.createDependencyChain([ DataStoreCleanupOperation.self, UnenrollApplicationOperation.self])
        SDKOperationQueue.workerQueue.addOperations(operations, waitUntilFinished: true)
        self.markOperationComplete()
    }
    
}
