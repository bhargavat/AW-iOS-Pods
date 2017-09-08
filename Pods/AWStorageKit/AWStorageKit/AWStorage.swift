//
//  AWStorage.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


public struct KeychainDataStore: AbstractKeychainDataStore {
    public var cryptor: StoreCryptor? = nil
    public init() {}
}

@objc
open class AWKeychain: NSObject, AbstractKeychainDataStore {
    open var cryptor: StoreCryptor? = nil
    public override init() {}

    @objc open func get(_ group: String, key: String) -> Data? {
        let data: Data? = (self as AbstractKeychainDataStore).get(group, key: key)
        return data
    }

    @objc open func set(_ group: String, key: String, value: Data?) -> Bool {
        var store: AbstractKeychainDataStore = self
        return store.set(group, key: key, value: value)
    }
}

public struct SQLiteDatabase {
    fileprivate var path: String
    public init(sqliteFilePath: String? = nil) {
        self.path = sqliteFilePath ?? SQLiteDatabase.documentsLocalSettingsFilepath()
    }

    public func getDatastore(_ group: String) -> LocalSettingsDataStore {
        let store = LocalSettingsDataStore(path: self.path, group: group)
        _ = store.createTableIfNotExists(group)
        return store
    }

    public static func documentsLocalSettingsFilepath(_ filename: String = "AWSettings.sqlite") -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return (documentsPath as NSString).appendingPathComponent(filename)
    }
}


open class LocalSettingsDataStore: AbstractSQLiteDataStore {
    open var cryptor: StoreCryptor? = nil
    open var database: OpaquePointer? = nil
    open var group: String = "Settings"
    fileprivate static let syncQueue: DispatchQueue = DispatchQueue(label: "com.air-watch.settings.control", attributes: [])
    public init(path: String, group: String) {
        self.database = self.open(path)
        self.group = group
    }
    deinit {
        _ = self.close()
    }

    open func get<DR: DataRepresentable>(_ key: String) -> DR? {
        let dataStore = self
        var result: DR? = nil
        LocalSettingsDataStore.syncQueue.sync {
            result =  dataStore.get(dataStore.group, key: key)
        }
        return result
    }

    @discardableResult open func set<DR: DataRepresentable>(_ key: String, value: DR?) -> Bool {
        var dataStore = self
        var result: Bool = false
        LocalSettingsDataStore.syncQueue.sync {
            result =  dataStore.set(dataStore.group, key: key, value: value)
        }
        return result
    }

    @discardableResult open func clear() -> Bool {
        var dataStore = self
        var result: Bool = false
        LocalSettingsDataStore.syncQueue.sync {
            result = dataStore.clearGroup(dataStore.group)
        }
        return result
    }

}

public struct InMemoryKeyValueStore: InMemoryDataStore {
    public var cryptor: StoreCryptor? = nil
    public var store: [String : [String : Data]] = [:]
    public init() {}
}
