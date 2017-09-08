//
//  LocakableDataStores.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWStorage

public let AES256KeySize = 32

private let MasterKeySize = AES256KeySize
private let TouchIDKeySize = AES256KeySize
private let SessionKeySize = AES256KeySize

open class ApplicationDataStoreLocker {
    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var securingDatastore: ApplicationDataStore
    var keyMaker: MasterKeyMaker

    public init(dataStore: ApplicationDataStore) {
        self.securingDatastore = dataStore
        self.itemQueryProvider = dataStore.itemQueryProvider
        self.keyMaker = MasterKeyProvider(itemQueryProvider: itemQueryProvider, datastore: dataStore.keyStore)
    }

    var isLocked: Bool {
        return self.securingDatastore.masterDataStore.cryptor == nil
    }

    func lockDataStore() -> Bool {
        self.securingDatastore.masterDataStore.cryptor = nil
        return true
    }

    func validateDataStore(key: ManagedKey) -> Bool{
        return self.keyMaker.validate(key: key)
    }

    func unlockDataStore(key: ManagedKey) -> Bool {
        guard self.keyMaker.validate(key: key) else {
            return false
        }

        let cryptor = MasterKeyCryptor(itemQueryProvider: self.itemQueryProvider, dataStore: self.securingDatastore.keyStore, key: key)
        self.securingDatastore.masterDataStore.cryptor = cryptor
        return true
    }

    func setupSessionKey() -> Data? {
        guard
            let masterKeyCryptor = self.securingDatastore.masterDataStore.cryptor as? MasterKeyCryptor,
            let masterKey = masterKeyCryptor.decryptMasterKey(key: masterKeyCryptor.decryptionKey)
        else {
            log(error: "Must be unlocked before Session key can be created")
            return nil
        }

        let sessionKey = Data.randomData(count: SessionKeySize)
        var masterKeyprovider = self.keyMaker
        do {
            if
                let masterkeyHash = masterKey.sha512,
                let encryptedMasterKeywithSessionkey = try SecureDataMessage.defaultMessage.encrypt(masterKey, key: sessionKey),
                let encryptedMasterKeyHashWithSessionKey = try SecureDataMessage.defaultMessage.encrypt(masterkeyHash, key: sessionKey) {
                masterKeyprovider.masterKeyEncryptedWithSessionKey = encryptedMasterKeywithSessionkey
                masterKeyprovider.masterKeyVerificationEncryptedWithSessionKey = encryptedMasterKeyHashWithSessionKey
                return sessionKey
            }
        } catch let error {
            log(error: "Failed to create session key: \(error)")
            return nil
        }

        return nil
    }

    func setupTouchIDKey() -> Data? {
        guard
            let masterKeyCryptor = self.securingDatastore.masterDataStore.cryptor as? MasterKeyCryptor,
            let masterKey = masterKeyCryptor.decryptMasterKey(key: masterKeyCryptor.decryptionKey)
            else {
                log(error: "Must be unlocked before Session key can be created")
                return nil
        }
        

        let touchIDkey = Data.randomData(count: TouchIDKeySize)
        var masterKeyprovider = self.keyMaker
        do {
            if let encryptedMasterKeywithTouchId = try SecureDataMessage.defaultMessage.encrypt(masterKey, key: touchIDkey),
                let masterkeyHash = masterKey.sha512,
                let encryptedMasterKeyHashWithTouchID = try SecureDataMessage.defaultMessage.encrypt(masterkeyHash, key: touchIDkey) {
                masterKeyprovider.masterKeyEncryptedWithTouchIDKey = encryptedMasterKeywithTouchId
                masterKeyprovider.masterKeyVerificationEncryptedWithTouchIDKey = encryptedMasterKeyHashWithTouchID
                return touchIDkey
            }
        } catch let error {
            log(error: "Failed to create touchID key: \(error)")
            return nil
        }
        return nil
    }

    var isInitialized: Bool {
        return self.keyMaker.masterKeyEncryptedWithCryptyKey != nil
    }


    func changeKey(key: ManagedKey, newCryptKey: Data, passcodeData: Data) -> Bool {
        let masterKeyprovider = self.keyMaker
        guard masterKeyprovider.validate(key: key) else {
            log(error: "current Key \(key) failed verification. Can not change to new key. returning without changing key...")
            return false
        }

        if let decryptedMasterKey = masterKeyprovider.decryptMasterKey(key: key) {
            return setupMasterKey(masterKey: decryptedMasterKey, cryptKey: newCryptKey, passcodeData: passcodeData)
        }

        log(error: "Master Key decryption failed with the provided Key \(key). returning without changing key...")
        return false
    }


    func resetStore(newCryptKey: Data, passcodeData: Data) -> Bool {
        let masterKey = Data.randomData(count: MasterKeySize)
        return self.setupMasterKey(masterKey: masterKey, cryptKey: newCryptKey, passcodeData: passcodeData)
    }

    private func setupMasterKey(masterKey: Data, cryptKey: Data, passcodeData: Data) -> Bool {
        let centennial = Data.randomData(count: AES256KeySize)
        var masterKeyprovider = self.keyMaker
        do {
            if let encryptedMasterKey = try SecureDataMessage.defaultMessage.encrypt(masterKey, key: cryptKey),
                let passcodeDataHash = passcodeData.sha256,
                let encryptedPasscodeData = try SecureDataMessage.defaultMessage.encrypt(passcodeData, key: masterKey),
                let encryptedPasscodeDataHash = try SecureDataMessage.defaultMessage.encrypt(passcodeDataHash, key: masterKey),
                let centennialHash = centennial.sha256,
                let encryptedCentennial = try SecureDataMessage.defaultMessage.encrypt(centennial, key: masterKey),
                let encryptedCentennialHash = try SecureDataMessage.defaultMessage.encrypt(centennialHash, key: masterKey) {

                masterKeyprovider.masterKeyEncryptedWithCryptyKey = encryptedMasterKey

                masterKeyprovider.encryptedPasscode = encryptedPasscodeData
                masterKeyprovider.encryptedPasscodeHash = encryptedPasscodeDataHash

                masterKeyprovider.encryptedCentennial = encryptedCentennial
                masterKeyprovider.encryptedCentennialHash = encryptedCentennialHash

                let cryptor = MasterKeyCryptor(itemQueryProvider: self.itemQueryProvider, dataStore: self.securingDatastore.keyStore, key: ManagedKey.cryptKey(cryptKey))
                self.securingDatastore.masterDataStore.cryptor = cryptor
                self.securingDatastore.cryptKeyWaitingToEscrow = cryptKey
                return true
            }
        } catch let error {
            log(error: "Failed create necessary Keys to reset passcode: \(error)")
        }
        return false
    }

}
