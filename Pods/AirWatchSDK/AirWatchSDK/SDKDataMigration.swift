//
//  MigrationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage

protocol DataMigrationOperations {
    var applicationDataStore: ApplicationDataStore { get set}
    func migrationOperations() -> [Operation]
}
extension DataMigrationOperations {
    internal func migrationOperations() -> [Operation] {
        return [SDKDataMigrationFrom_0_1(applicationDataStore: applicationDataStore)]
    }
}

/** 
 Migration of SDK data from keychain or local data store.
 */
class SDKDataMigration: DataMigrationOperations {
    internal var applicationDataStore: ApplicationDataStore
    
    init(context: ApplicationDataStore) {
        self.applicationDataStore   = context
    }
    
    /**
     This will perform the migration on the thread it is on.
     */
    func performMigration() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperations(migrationOperations(), waitUntilFinished: true)
    }
}
