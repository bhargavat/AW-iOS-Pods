//
//  AWEncryptedStore.swift
//  AWEncryptedStoreKit
//
//  Copyright © 2017 vmware. All rights reserved.
//

import Foundation
import EncryptedCoreData
import CoreData

public final class AWEncryptedStoreOptions : NSObject {
    public static let StoreType = "AWEncryptedStore"
    public static let MigrateDataFromStoreType = "AWEncryptedStoreMigrateDataFromStoreType"
    public static let MigrateDataFromStoreLocation = "AWEncryptedStoreMigrateDataFromStoreLocation"
    public static let StorePassphraseKey = EncryptedStorePassphraseKey
}

public let AWEncryptedStoreType = AWEncryptedStoreOptions.StoreType
public let AWEncryptedStorePassphrase = AWEncryptedStoreOptions.StorePassphraseKey
public let AWEncryptedStoreMigrateDataFromStoreType = AWEncryptedStoreOptions.MigrateDataFromStoreType
public let AWEncryptedStoreMigrateDataFromStoreLocation = AWEncryptedStoreOptions.MigrateDataFromStoreLocation

public final class AWEncryptedStoreBuilder : NSObject {
    
    private var options: [AnyHashable:Any]
    private var storeURL: URL
    private var coordinator: NSPersistentStoreCoordinator
    private var configuration: String?
    private let defaultOptions = [NSMigratePersistentStoresAutomaticallyOption: true,
                             NSInferMappingModelAutomaticallyOption: true]
    
    public init(withStoreURL url: URL, coordinator: NSPersistentStoreCoordinator) {
        self.storeURL = url
        self.coordinator = coordinator
        options = defaultOptions
    }
    
    public func passphrase(passphrase: String) -> AWEncryptedStoreBuilder {
        options[AWEncryptedStorePassphrase] = passphrase
        return self
    }
    
    public func passphrase(withKey key: Data) -> AWEncryptedStoreBuilder {
        let str = "x'\(key.hexValue())'"
        options[AWEncryptedStorePassphrase] = str
        return self
    }
    
    public func error(domain: String, messageKey: String) -> AWEncryptedStoreBuilder {
        options[EncryptedStoreErrorDomain] = domain
        options[EncryptedStoreErrorMessageKey] = messageKey
        return self
    }
    
    public func cacheSize(size: Int) -> AWEncryptedStoreBuilder {
        options[EncryptedStoreCacheSize] = size
        return self
    }
    
    public func extra(options: [AnyHashable:Any]) -> AWEncryptedStoreBuilder {
        for (key, val) in options {
            self.options[key] = val
        }
        return self
    }
    
    public func configuration(configurationName: String) -> AWEncryptedStoreBuilder {
        self.configuration = configurationName
        return self
    }
    
    public func migrateDataFromStore(storeType: String, storeLocation: URL) -> AWEncryptedStoreBuilder {
        options[AWEncryptedStoreMigrateDataFromStoreType] = storeType
        options[AWEncryptedStoreMigrateDataFromStoreLocation] = storeLocation
        return self
    }
    
    public func build() throws -> NSPersistentStore {
        NSPersistentStoreCoordinator.registerStoreClass(AWEncryptedStore.self, forStoreType: AWEncryptedStoreOptions.StoreType)
        options[NSStoreTypeKey] = AWEncryptedStoreType
        return try coordinator.addPersistentStore(ofType: AWEncryptedStoreType, configurationName: self.configuration, at: storeURL, options: options)
    }

}

@objc public final class AWEncryptedStore : EncryptedStore {
    
    typealias Builder = AWEncryptedStoreBuilder
    
    override public var type: String {
        get{
            return AWEncryptedStoreType
        }
    }
    
    override public func didAdd(to coordinator: NSPersistentStoreCoordinator) {
        super.didAdd(to: coordinator)
        do{
            let dataMigrated = try migrateData(toCoordinator: coordinator)
            log(info: "data migrated = \(dataMigrated)")
        }catch let e{
            log(error: "could not migrate data \(e)")
        }
    }
    
    public func migrateData(toCoordinator coordinator: NSPersistentStoreCoordinator) throws -> Bool {
        guard let opt = options else {
            return false
        }
        guard let storeUrl = opt[AWEncryptedStoreMigrateDataFromStoreLocation] as? URL,
            let storeType = opt[AWEncryptedStoreMigrateDataFromStoreType] as? String else {
                log(debug: "could not migrate, missing migration information")
            return false
        }
        
        guard storeUrl != self.url else {
            log(error: "could not migrate, from storeUrl: \(storeUrl) should not match with self storeUrl:\(String(describing: self.url))")
            return false
        }
        
        let migration = AWEncryptedDataMigration(storeUrl, storeType: storeType)
        var migrated = false
        if migration.canMigrateData(){
            migrated = try migration.migrateData(toCoordinator: coordinator)
        }
        
        return migrated
        
    }


}
