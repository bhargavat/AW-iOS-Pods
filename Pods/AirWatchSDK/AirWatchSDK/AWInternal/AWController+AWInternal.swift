//
//  AWController+AWInternal.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWError
import AWServices

extension AWSDKError {
    enum InvalidOperations: AWSDKErrorType {
        case containerLocked
        case emptyData
        case missingOrInvalidKey
        case invalidSharedDataStore
        case invalidDataStoreType
        
        var code: Int {
            switch self {
            case .containerLocked       : return 0
            case .emptyData             : return 1
            case .missingOrInvalidKey   : return 2
            case .invalidSharedDataStore: return 3
            case .invalidDataStoreType  : return 4
            }
        }
    }
}

public extension AWController {

    @objc
    public func canAccessProtectedData() -> Bool {
        guard let store = self.context as? ApplicationDataStore else {
            log(error: "Invalid Store, Do not know how to retrieve Application key")
            return false
        }

        let lockableStore = ApplicationDataStoreLocker(dataStore: store)
        return lockableStore.isLocked == false
    }

    @objc
    public func wipeAllDataAndRestartSDK() {

        let dataStoreCleanup = DataStoreCleanupOperation(sdkController: self, presenter: self.presenter, dataStore: self.context)
        dataStoreCleanup.completionBlock = {
            AWController.sharedInstance.start()
        }

        SDKOperationQueue.sharedQueue.addOperation(dataStoreCleanup)
    }
    
    @objc
    public func stop() {
        SDKOperationQueue.reset()
    }

    public func decrypt(sharedData: Data) throws -> Data? {

        guard let store = self.context as? ApplicationDataStore else {
            throw AWSDKError.InvalidOperations.invalidDataStoreType
        }

        guard store.shared else {
            throw AWSDKError.InvalidOperations.invalidSharedDataStore
        }

        guard self.canAccessProtectedData() else {
            log(error: "Data Store is locked, Cannot perform decryption")
            throw AWSDKError.InvalidOperations.containerLocked
        }

        guard let sharedContainerKey = AWController.sharedInstance.context.sharedContainerKey, sharedContainerKey.count > 0 else {
            log(warning: "Shared Container key is empty")
            throw AWSDKError.InvalidOperations.missingOrInvalidKey
        }

        return SecureDataMessage.decryptObject(sharedData, key: sharedContainerKey)
    }

    public func encrypt(sharedData: Data) throws -> Data? {

        guard let store = self.context as? ApplicationDataStore else {
            throw AWSDKError.InvalidOperations.invalidDataStoreType
        }

        guard store.shared else {
            throw AWSDKError.InvalidOperations.invalidSharedDataStore
        }

        guard self.canAccessProtectedData() else {
            log(error: "Data Store is locked, Cannot perform encryption")
            throw AWSDKError.InvalidOperations.containerLocked
        }

        guard let sharedContainerKey = AWController.sharedInstance.context.sharedContainerKey, sharedContainerKey.count > 0 else {
            log(warning: "Shared Container key is empty. Cannot Encrypt")
            throw AWSDKError.InvalidOperations.missingOrInvalidKey
        }

        let encryptionHelper = SecureDataMessage.AES256CBCWithIV
        return encryptionHelper.encryptObject(sharedData, key: sharedContainerKey)
    }

    @objc
    public func decrypt(_ data: Data?, error: NSErrorPointer) -> Data? {
        guard let data = data else {
            log(warning: "Data is incomplete")
            error?.pointee = AWSDKError.InvalidOperations.emptyData.error
            return nil
        }

        guard self.canAccessProtectedData() else {
            log(error: "Data Store is locked, Can not perform encryption/decryption")
            error?.pointee = AWSDKError.InvalidOperations.containerLocked.error
            return nil
        }

        guard let appKey = AWController.sharedInstance.context.applicationKey, appKey.count > 0 else {
            log(warning: "Application key is empty. Cannot Decrypt")
            error?.pointee = AWSDKError.InvalidOperations.missingOrInvalidKey.error
            return nil
        }
        
        guard appKey.hasValidApplicationKeySize else {
            log(warning: "Cannot decrypt, Application key is not valid")
            error?.pointee = AWSDKError.InvalidOperations.missingOrInvalidKey.error
            return nil
        }
        
        return SecureDataMessage.decryptObject(data, key: appKey)
    }
    
    @objc
    public func encrypt(_ data: Data?, error: NSErrorPointer) -> Data? {
        guard let data = data else {
            log(warning: "Data is incomplete")
            error?.pointee = AWSDKError.InvalidOperations.emptyData.error
            return nil
        }

        guard self.canAccessProtectedData() else {
            log(error: "Data Store is locked, Can not perform encryption/decryption")
            error?.pointee = AWSDKError.InvalidOperations.containerLocked.error
            return nil
        }

        guard let appKey = AWController.sharedInstance.context.applicationKey, appKey.count > 0 else {
            log(warning: "Application key is empty")
            error?.pointee = AWSDKError.InvalidOperations.missingOrInvalidKey.error
            return nil
        }
        
        guard appKey.hasValidApplicationKeySize else {
            log(warning: "Cannot encrypt, Application key is not valid")
            error?.pointee = AWSDKError.InvalidOperations.missingOrInvalidKey.error
            return nil
        }

        return SecureDataMessage.defaultMessage.encryptObject(data, key: appKey)
    }
}
