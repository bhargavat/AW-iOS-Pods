//
//  DataMigration.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage

protocol MigrationDatasource {
    var keychain: AbstractKeychainDataStore { get }
    func localStore(name: String) -> LocalSettingsDataStore
}

extension MigrationDatasource {
    var keychain: AbstractKeychainDataStore {
        return KeychainDataStore()
    }
    
    func localStore(name: String) -> LocalSettingsDataStore {
        return SQLiteDatabase().getDatastore(name)
    }
}

class MigrationOperation: Operation {
    func markOperationComplete() {
        isFinished = true
    }
    
    fileprivate var _finished: Bool = false
    override final var isFinished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }
}

protocol MigrationProtocol {
    // logic to decide whether migration is necessary
    func canMigrate() -> Bool
    
    // implement the logic for migrating data
    func performMigration()
}
