//
//  MasterKeyEncryptedDataStore.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWCrypto

public enum cryptorType: Int {
    case cryptKeyCryptor     = 0
    case sessionKeyCryptor   = 1
}

public enum ManagedKey {
    case cryptKey(Data)
    case touchIDKey(Data)
    case sessionKey(Data)
}

struct MasterKeyCryptor: MasterKeyMaker, StoreCryptor {
    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var datastore: AbstractKeyValueStore
    var decryptionKey: ManagedKey

    init(itemQueryProvider: KeyValueStoreItemQueryProvider, dataStore: AbstractKeyValueStore, key: ManagedKey) {
        self.itemQueryProvider = itemQueryProvider
        self.datastore = dataStore
        self.decryptionKey = key
    }

    func encryptObject<DR: DataRepresentable>(_ object: DR?) -> Data? {
        guard let masterKey = self.decryptMasterKey(key: self.decryptionKey) else {
            return nil
        }

        let helpingCryptor = SimpleKeyCryptor(key: masterKey)
        return helpingCryptor.encryptObject(object)
    }

    func decryptObject<DR: DataRepresentable>(_ data: Data?) -> DR? {
        guard let masterKey = self.decryptMasterKey(key: self.decryptionKey) else {
            return nil
        }

        let helpingCryptor = SimpleKeyCryptor(key: masterKey)
        return helpingCryptor.decryptObject(data)
    }
}
