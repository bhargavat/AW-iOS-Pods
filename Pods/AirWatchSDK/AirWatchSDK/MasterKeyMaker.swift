//
//  MasterKeyHelper.swift
//  AWSecureSharedStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCrypto
import AWStorage

protocol MasterKeyMaker: DataStoreItemQueryProvider {
    var datastore: AbstractKeyValueStore { get set }

    var masterKeyEncryptedWithCryptyKey: Data? { get set }
    var masterKeyEncryptedWithTouchIDKey: Data? { get set }
    var masterKeyVerificationEncryptedWithTouchIDKey: Data? { get set }
    var masterKeyEncryptedWithSessionKey: Data? { get set }
    var masterKeyVerificationEncryptedWithSessionKey: Data? { get set }

    var encryptedCentennial: Data? { get set }
    var encryptedCentennialHash: Data? { get set }

    var encryptedPasscode: Data? { get set }
    var encryptedPasscodeHash: Data? { get set }

    func decryptMasterKey(key: ManagedKey) -> Data?
    func validate(key: ManagedKey) -> Bool

    mutating func clearMasterKeyMaker()
}

internal extension Data {
    func decryptedData(key: Data) -> Data? {
        return SecureDataMessage.decryptObject(self, key: key)
    }
}

extension MasterKeyMaker {
    var masterKeyEncryptedWithCryptyKey: Data? {
        get {
            return datastore.fetch(itemQueryProvider.MasterKeyEncryptedWithCryptKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.MasterKeyEncryptedWithCryptKey, value: newValue)
        }
    }

    var masterKeyEncryptedWithTouchIDKey: Data? {
        get {
            return datastore.fetch(itemQueryProvider.MasterKeyEncryptedWithTouchIDKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.MasterKeyEncryptedWithTouchIDKey, value: newValue)
        }
    }

    var masterKeyVerificationEncryptedWithTouchIDKey: Data? {
        get {
            return datastore.fetch(itemQueryProvider.MasterKeyVerificationEncryptedWithTouchIDKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.MasterKeyVerificationEncryptedWithTouchIDKey, value: newValue)
        }
    }

    var masterKeyEncryptedWithSessionKey: Data? {
        get {
            return datastore.fetch(itemQueryProvider.MasterKeyEncryptedWithSessionKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.MasterKeyEncryptedWithSessionKey, value: newValue)
        }
    }

    var masterKeyVerificationEncryptedWithSessionKey: Data? {
        get {
            return datastore.fetch(itemQueryProvider.MasterKeyVerificationEncryptedWithSessionKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.MasterKeyVerificationEncryptedWithSessionKey, value: newValue)
        }
    }


    var encryptedPasscode: Data? {
        get {
            return self.datastore.fetch(itemQueryProvider.EncryptedPasscode)
        }

        set {
            _ = self.datastore.set(itemQueryProvider.EncryptedPasscode, value: newValue)
        }
    }


    var encryptedPasscodeHash: Data? {
        get {
            return self.datastore.fetch(itemQueryProvider.EncryptedPasscodeHash)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.EncryptedPasscodeHash, value: newValue)
        }
    }

    var encryptedCentennial: Data?{
        get {
            return self.datastore.fetch(itemQueryProvider.CentennialEncryptedWithMasterKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.CentennialEncryptedWithMasterKey, value: newValue)
        }
    }

    var encryptedCentennialHash: Data? {
        get {
            return self.datastore.fetch(itemQueryProvider.CentennialVerificationEncryptedWithMasterKey)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.CentennialVerificationEncryptedWithMasterKey, value: newValue)
        }
    }

    var cryptKeyToEscrow: Data? {
        get {
            return self.datastore.fetch(itemQueryProvider.CryptKeyToEscrow)
        }
        set {
            _ = self.datastore.set(itemQueryProvider.CryptKeyToEscrow, value: newValue)
        }
    }

    @inline(__always)
    func decryptMasterKey(key: ManagedKey) -> Data? {

        switch key {
        case .cryptKey(let cryptKey):
            return self.decryptMasterKey(cryptKey: cryptKey)

        case .touchIDKey(let touchIDKey):
            return self.decryptMasterKey(touchIDKey: touchIDKey)

        case .sessionKey(let sessionKey):
            return self.decryptMasterKey(sessionKey: sessionKey)
        }
    }

    @inline(__always)
    func validate(key: ManagedKey) -> Bool {
        switch key {
        case .cryptKey(let cryptKey):
            guard let decryptedMasterKey = self.decryptMasterKey(cryptKey: cryptKey) else {
                log(error: "Attempt to get master key from CryptKey Failed. Error decrypting masterkey")
                return false
            }
            
            let canValidateWithCentennials = validateCentennial(masterKey: decryptedMasterKey)
            if canValidateWithCentennials {
                log(debug: "Just validated credentials with centennails saved with master key derived from Crypt Key")
                return true
            }
            
            
            // Let's try one last time with user passcode for old apps
            guard
                let decryptedPasscodeHash = self.encryptedPasscodeHash?.decryptedData(key: decryptedMasterKey),
                let decryptedPasscode = self.encryptedPasscode?.decryptedData(key: decryptedMasterKey)
                else {
                    log(error: "Failed to verify master key using user passcode or passcode hash. Will fail Crypt Key validation")
                    return false
            }
            
            let validatedMasterKey =  (decryptedPasscode.sha256 == decryptedPasscodeHash)
            log(info: "Attempt to get master key from CryptKey \(validatedMasterKey ? "successful": "failed")")
            return validatedMasterKey

        case .touchIDKey(let touchIDKey):
            guard let decryptedMasterKey = self.decryptMasterKey(touchIDKey: touchIDKey) else {
                log(error: "Attempt to get master key from Touch ID Key Failed. Error decrypting masterkey")
                return false
            }
            
            let canValidateWithCentennials = validateCentennial(masterKey: decryptedMasterKey)
            if canValidateWithCentennials {
                log(debug: "Just validated credentials with centennails saved with master key derived from Touch ID Key")
                return true
            }
            
            // Let's try one last time with validations with old PBE apps
            guard
                let decryptedMasterKeyHash = self.masterKeyVerificationEncryptedWithTouchIDKey?.decryptedData(key: touchIDKey)
                else {
                    log(error: "Failed to get master key verification using Touch ID Key. Will fail Touch ID Key validation")
                    return false
            }
            
            let validatedMasterKey =  (decryptedMasterKey.sha512 == decryptedMasterKeyHash)
            log(info: "Attempt to get master key from Touch ID Key \(validatedMasterKey ? "successful": "failed")")
            return validatedMasterKey
            
        case .sessionKey(let sessionKey):
            guard let decryptedMasterKey = self.decryptMasterKey(sessionKey: sessionKey) else {
                log(error: "Attempt to get master key from Session ID Key Failed. Error decrypting masterkey")
                return false
            }
            
            let canValidateWithCentennials = validateCentennial(masterKey: decryptedMasterKey)
            if canValidateWithCentennials {
                log(debug: "Just validated credentials with centennails saved with master key derived from Session Key")
                return true
            }
            
            // Let's try one last time with validations with old PBE apps
            guard
                let decryptedMasterKeyHash = self.masterKeyVerificationEncryptedWithSessionKey?.decryptedData(key: sessionKey)
                else {
                    log(error: "Failed to get master key verification using Session ID Key. Will fail Session ID Key validation")
                    return false
            }
            
            let validatedMasterKey =  (decryptedMasterKey.sha512 == decryptedMasterKeyHash)
            log(info: "Attempt to get master key from Session ID Key \(validatedMasterKey ? "successful": "failed")")
            
            return validatedMasterKey
        }
    }

    @inline(__always)
    func validateCentennial(masterKey: Data) -> Bool {
        guard
            let encryptedCentennial = self.encryptedCentennial,
            let encryptedCentennialHash = self.encryptedCentennialHash
            else {
                log(info: "Encrypted Centennail and corresponding hash no not exist. looks like we are coming from an update from old app.")
                return false
        }

        guard
            let decryptedCentennialHash = encryptedCentennialHash.decryptedData(key: masterKey),
            let decryptedCentennial = encryptedCentennial.decryptedData(key: masterKey)
            else {
                log(info: "Encrypted Centennail and/or corresponding hash no not exist. looks like we are coming from an update from old app.")
                return false
        }


        //We have Centennial stored with master key. We should use it to verify
        log(debug: "Encrypted Centennail and corresponding hash exist. Will Verify master key with them")
        return (decryptedCentennial.sha256 == decryptedCentennialHash)
    }

    @inline(__always)
    func decryptedUserPasscodeHash(_ masterKey: Data) -> Data? {
        guard let encryptedPasscodeHash: Data = self.datastore.fetch(itemQueryProvider.EncryptedPasscodeHash)else { return nil }

        do {
            return try SecureDataMessage.decrypt(encryptedPasscodeHash, key: masterKey)
        } catch let error {
            log(error: "Failed to decrypt Passcode Hash : \(error), with Master Key: \(masterKey)")
        }

        return nil
    }

    @inline(__always)
    func decryptedUserPasscode(_ masterKey: Data) -> Data? {
        guard let encryptedPasscode: Data = self.datastore.fetch(itemQueryProvider.EncryptedPasscode) else { return nil }
        do {
            return try SecureDataMessage.decrypt(encryptedPasscode, key: masterKey)
        } catch let error {
            log(error: "Failed to decrypt Passcode: \(error), with Master Key: \(masterKey)")
        }
        return nil
    }

    @inline(__always)
    func decryptMasterKey(cryptKey: Data) -> Data? {
        guard
            let encryptedMasterKey = self.masterKeyEncryptedWithCryptyKey
            else { return nil }

        do {
            return try SecureDataMessage.decrypt(encryptedMasterKey, key: cryptKey)
        } catch let error {
            log(error: "Failed to Decrypt Master Key: \(error), with Crypt Key: \(cryptKey)")
        }
        return nil
    }

    @inline(__always)
    func decryptMasterKey(touchIDKey: Data) -> Data? {
        guard
            let encryptedMasterKey = self.masterKeyEncryptedWithTouchIDKey
            else { return nil }

        do {
            return try SecureDataMessage.decrypt(encryptedMasterKey, key: touchIDKey)
        } catch let error {
            log(error: "Failed to Decrypt Master Key: \(error), with Crypt Key: \(touchIDKey)")
        }
        return nil
    }

    @inline(__always)
    func decryptMasterKey(sessionKey: Data) -> Data? {
        guard
            let encryptedMasterKey = self.masterKeyEncryptedWithSessionKey
            else { return nil }

        do {
            return try SecureDataMessage.decrypt(encryptedMasterKey, key: sessionKey)
        } catch let error {
            log(error: "Failed to Decrypt Master Key: \(error), with Crypt Key: \(sessionKey)")
        }
        return nil
    }

    mutating func clearMasterKeyMaker() {
        self.masterKeyEncryptedWithCryptyKey = nil
        self.masterKeyEncryptedWithTouchIDKey = nil
        self.masterKeyVerificationEncryptedWithTouchIDKey = nil
        self.masterKeyEncryptedWithSessionKey = nil
        self.masterKeyVerificationEncryptedWithSessionKey = nil
        self.encryptedCentennial = nil
        self.encryptedCentennialHash = nil
        self.encryptedPasscode = nil
        self.encryptedPasscodeHash = nil
    }
}

struct MasterKeyProvider: MasterKeyMaker {
    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var datastore: AbstractKeyValueStore
}
