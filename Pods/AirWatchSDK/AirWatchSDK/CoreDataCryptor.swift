//
//  CoreDataCryptor.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.

import Foundation
import AWEncryptedStoreKit
import CoreData
import AWStorage
import AWError

extension AWError.SDK {
     enum EncryptedStore: AWErrorType {
        case storeIsLocked
        case storeTypeNotSupported(String)
        case storeMigrationFailed
        case fileDoesNotExist
        case internalEncryptionError
        case internalError
        
        var code: Int {
            switch self {
            case .storeIsLocked:
                return AWSDKEncryptedStoreError.storeIsLocked.rawValue
            case .storeTypeNotSupported( _):
                return AWSDKEncryptedStoreError.storeTypeNotSupported.rawValue
            case .storeMigrationFailed:
                return AWSDKEncryptedStoreError.storeMigrationFailed.rawValue
            case .fileDoesNotExist:
                return AWSDKEncryptedStoreError.fileDoesNotExist.rawValue
            case .internalEncryptionError:
                return AWSDKEncryptedStoreError.internalEncryptionError.rawValue
            case .internalError:
                return AWSDKEncryptedStoreError.internalError.rawValue
            }
        }
        
        var domain: String {
            return AWSDKErrorDomains.encryptedStore
        }
        
        var userInfo: AWErrorInfoDict? {
            switch self {
            case .storeTypeNotSupported(let storeType):
                return ["StoreTypeNotSupported" : "StoreType: \(storeType) not supported"]
            default:
                return nil
            }
        }
    }
}

private let StoreEncryptionKeySize = AES256KeySize
internal struct EncryptedStoreKeyProvider {

    var cryptor: StoreCryptor
    var keyStore: AbstractKeyValueStore = KeychainDataStore()
    static let account = Bundle.main.bundleIdentifier ?? "awcoredata.encryption.account"
    static let service = "awcoredata.encryption.service"
    
    init(storeCryptor: StoreCryptor) {
        self.cryptor = storeCryptor
        self.keyStore.cryptor = cryptor
    }
    
    mutating func key() -> Data? {
        
        let existingStoreEncryptionKey: SDKSharedContainerKey? = self.keyStore.get(EncryptedStoreKeyProvider.account, key: EncryptedStoreKeyProvider.service)
        if let existingKey = existingStoreEncryptionKey {
            log(debug: "Returning previously generated StoreEncryption Key")
            return existingKey.keyData
        }
        
        log(info: "Store Encryption Key was never generated for this App or can not parse the existing key. Going to generate a new one.")
        guard let generatedKey = SDKSharedContainerKey(keySize: StoreEncryptionKeySize), generatedKey.isValidKey else{
            log(error: "Cannot generate a valid key for Store Encryption. Returning nil")
            return nil
        }
        _ = self.keyStore.set(EncryptedStoreKeyProvider.account, key: EncryptedStoreKeyProvider.service, value: generatedKey)
        return generatedKey.keyData
    }

    static func clearKey() -> Bool {
        var keyChainStore = KeychainDataStore()
        let nilData: Data? = nil
        return keyChainStore.set(EncryptedStoreKeyProvider.account, key: EncryptedStoreKeyProvider.service, value: nilData)
    }
}

public class AWPersistentStoreCoordinator: NSPersistentStoreCoordinator {
    
    @objc
    public func createEncryptedStore(configurationName configuration: String?, at storeURL: URL, options: [AnyHashable : Any]? = nil) throws -> NSPersistentStore {
        let storeKey = try self.getStoreKey()
        let storeBuilder = AWEncryptedStoreBuilder(withStoreURL: storeURL, coordinator: self)
            .passphrase(withKey: storeKey)
        
        if let opts = options {
            let _ = storeBuilder.extra(options: opts)
        }
        
        if let config = configuration {
            let _ = storeBuilder.configuration(configurationName: config)
        }
        
        return try storeBuilder.build()
    }
    
    @objc
    public func migrateDataFromStore(store previousStoreURL: URL, ofType storeType: String) throws -> Void {
        let migrator = AWEncryptedDataMigration(previousStoreURL, storeType: storeType)
        
        guard FileManager.default.fileExists(atPath: previousStoreURL.path) else {
            throw AWError.SDK.EncryptedStore.fileDoesNotExist.error
        }
        
        guard migrator.canMigrateData() else {
            throw AWError.SDK.EncryptedStore.storeTypeNotSupported(storeType).error
        }
        
        guard try migrator.migrateData(toCoordinator: self) else {
            throw AWError.SDK.EncryptedStore.storeMigrationFailed.error
        }
    }
    
    internal func getStoreKey() throws -> Data {
        let controller = AWController.sharedInstance
        guard controller.canAccessProtectedData() else {
            log(error: "Trying to access EncryptedStore Key while Store is locked")
            throw AWError.SDK.EncryptedStore.storeIsLocked.error
        }
        
        guard let appkey = controller.context.applicationKey else {
            log(error: "cannot retrieve application key")
            throw AWError.SDK.EncryptedStore.internalEncryptionError.error
        }
        
        let cryptor = SimpleKeyCryptor(key: appkey)
        var keyProvider = EncryptedStoreKeyProvider(storeCryptor: cryptor)
        
        guard let storeKey = keyProvider.key() else {
            throw AWError.SDK.EncryptedStore.internalError.error
        }

        return storeKey
    }
}







