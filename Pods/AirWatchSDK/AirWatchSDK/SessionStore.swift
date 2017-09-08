//
//  AWSessionStore.swift
//  AWStorage
//
//  Created by Anuj Panwar on 1/11/17.
//  Copyright © 2017 VMware, Inc. All rights reserved.
//

import Foundation
import AWCrypto
import AWStorage


fileprivate enum SessionStoreConstants: String {
    case PublicKey                 =  "publicKey.rsa"
    case PrivateKey                =  "privateKey.rsa"
}

struct GlobalSessionStore: DataStoreItemQueryProvider, AbstractKeychainDataStore {

    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var cryptor: StoreCryptor? = nil

    init(queryProvider: KeyValueStoreItemQueryProvider) {
        self.itemQueryProvider = queryProvider
    }

    var sessionTable: NSDictionary? {
        get {
            return self.fetch(itemQueryProvider.SessionTable)
        }
        set {
            _ = self.set(itemQueryProvider.SessionTable, value: newValue)
        }
    }

    var applictionKeyForGlobalSessionTable: String {
        let appKeyQuery = itemQueryProvider.ApplictionKeyForGlobalSessionTable
        //tablekey.<bunldeid>
        let appKeyForGlobalSessionTable = appKeyQuery.key + "." + appKeyQuery.group

        if appKeyQuery.group != Bundle.main.bundleIdentifier {
            log(warning: "no bundle id returned for app entry in session table")
        }

        return appKeyForGlobalSessionTable
    }

    mutating func addCurrentAppEntry(pubKey: SecKey) -> Bool {

        let sessionKeyStruct = GlobalSessionTableEntry(publicKey: pubKey, encrypedSession: nil)
        guard let sessionKeyStructData = sessionKeyStruct.toData() else {
            log(error: "error converting sessionKeyStruct to data. could not save app entry")
            return false
        }

        let sessionTableDict = self.sessionTable as? [String: Data]
        if sessionTableDict == nil {
            log(info: "found empty sessiontable, will add first entry")
        }
        var sessionTable = sessionTableDict ?? [:]

        let currentAppKey = self.applictionKeyForGlobalSessionTable
        sessionTable[currentAppKey] = sessionKeyStructData

        self.sessionTable = sessionTable as NSDictionary
        return true
    }

    mutating func removeAppEntry() {

        guard var sessionTableDict = self.sessionTable as? [String: Data] else {
            log(info: "no sessionTable found, no need to remove entry")
            return
        }
        sessionTableDict[self.applictionKeyForGlobalSessionTable] = nil
        //save back the table
        self.sessionTable = sessionTableDict as NSDictionary
    }


    func retrieveAppSessionInfo(privateKey: SecKey) -> AppSessionInfo? {

        guard let sessionTable = self.sessionTable as? [String: Data] else {
            log(error: "no sessionTable found")
            return nil
        }

        guard let sessionEntryData = sessionTable[self.applictionKeyForGlobalSessionTable] else {
            log(error: "public key entry not found: should not happen")
            return nil
        }

        guard let sessionEntry = GlobalSessionTableEntry.fromData(sessionEntryData) else {
            log(error: "error converting to AWSessionKeyStructure")
            return nil
        }

        guard let encryptedSessionInfo = sessionEntry.appSession else {
            log(error: "no encrypted session found")
            return nil

        }

        do {
            let decryptedSessionInfo = try PGPCryptor.decrypt(data: encryptedSessionInfo, privateKey: privateKey)
            guard let sessionInfo = AppSessionInfo.fromData(decryptedSessionInfo) else {
                log(error: "failed to convert current session data to structure")
                return nil
            }

            return sessionInfo

        } catch let error {
            log(error: "failed to decrypt current session with error: \(error)")
            return nil
        }

    }

    func doesGlobalSessionTableContainCurrentApplicationEntry() -> Bool {

        guard let sessionTable = self.sessionTable as? [String: Data] else {
            log(info: "no sessionTable found")
            return false
        }

        guard let sessionEntryData = sessionTable[self.applictionKeyForGlobalSessionTable] else {
            log(info: "public key entry not found for current app")
            return false
        }

        guard GlobalSessionTableEntry.fromData(sessionEntryData) != nil else {
            log(error: "invalid GlobalSessionTableEntry")
            return false
        }
        return true
    }

    mutating func setGlobalSession(newSessionInfo: AppSessionInfo) -> Bool {

        guard let sessionInfoData = newSessionInfo.toData() else {
            log(error: "could not convert session to to data, cannot update")
            return false
        }

        guard var sessionTableDict = self.sessionTable as? [String: Data] else {
            log(error: "no sessionTable found")
            return false
        }

        //indicates if all values were updated successfully
        var returnValue:Bool = true

        for (key, sessionStructData) in sessionTableDict {

            guard
                let sessionTableEntry = GlobalSessionTableEntry.fromData(sessionStructData)
            else {
                log(error: "corrupted sessionStructData for app: \(key)")
                returnValue = false
                continue
            }

            do {
                let encryptedUpdatedSession = try PGPCryptor.encrypt(data: sessionInfoData,publicKey: sessionTableEntry.publicKey)
                let updatedSessionEntry = GlobalSessionTableEntry(publicKey: sessionTableEntry.publicKey, encrypedSession: encryptedUpdatedSession)
                sessionTableDict[key] = updatedSessionEntry.toData()
            } catch let error {
                log(error: "failed to update session for app:" + key + "with error \(error)")
                returnValue = false
            }
        }

        self.sessionTable = sessionTableDict as NSDictionary
        return returnValue
    }

    //clears sessions from all entries
    mutating func clearSessionInfo() -> Bool {

        guard var sessionTableDict = self.sessionTable as? [String: Data] else {
            log(info: "no sessionTable found")
            return true
        }

        guard sessionTableDict.count > 0 else {
            log(error: "empty sessionTable found")
            return true
        }

        for (key, sessionStructData) in sessionTableDict {

            guard
                let sessionTableEntry = GlobalSessionTableEntry.fromData(sessionStructData)
            else {
                log(info: "no sessionEntry for app:"+key)
                continue
            }

            let newSessiontableEntry = GlobalSessionTableEntry(publicKey: sessionTableEntry.publicKey, encrypedSession: nil)
            sessionTableDict[key] = newSessiontableEntry.toData()
        }

        self.sessionTable = sessionTableDict as NSDictionary
        return true
    }


    //clears everything
    mutating func clearStore() {
        self.sessionTable = nil
    }
}


extension SecurityKeyPair: DataRepresentable {
    
    public static func fromData(_ data: Data?) -> Self? {

        guard
            let rsaKeyPairDict = NSDictionary.fromData(data)
        else {
            log(error: "failed to convert RSA keypair data to dictionary")
            return nil
        }

        guard
            let pubkeyData = rsaKeyPairDict[SessionStoreConstants.PublicKey.rawValue] as? Data,
            let privKeyData = rsaKeyPairDict[SessionStoreConstants.PrivateKey.rawValue] as? Data
        else {
            log(error: "failed to convert RSA keypair data to dictionary correctly")
            return nil
        }

        guard let publicKey = Data.secKeyRefFromPublicKeyData(pubkeyData) else {
            log(error: "failed to convert data to publickey")
            return nil

        }
        guard let privateKey = Data.secKeyRefFromPrivateKeyData(privKeyData) else {
            log(error: "failed to convert data to privateKey")
            return nil
        }

        let keyPair = self.init(publicKey: publicKey, privateKey: privateKey)
        return keyPair
    }

    public func toData() -> Data? {
        guard
            let publicKey = self.publicKey,
            let publicKeyData = Data.publicKeyData(publicKey)
        else {
            log(error: "failed to convert to publickey Data")
            return nil
        }

        guard
            let privateKey = self.privateKey,
            let privateKeyData = Data.privateKeyData(privateKey)
        else {
            log(error: "failed to convert to private Data")
            return nil
        }

        var keyPairDictionary: [String: Data] = [:]
        keyPairDictionary[SessionStoreConstants.PublicKey.rawValue] = publicKeyData
        keyPairDictionary[SessionStoreConstants.PrivateKey.rawValue] = privateKeyData
        guard let keyPairDictData = (keyPairDictionary as NSDictionary).toData() else {
            log(error: "failed to convert to keyPair to Data")
            return nil
        }

        return keyPairDictData
    }
}


class RSAKeyPairStore: DataStoreItemQueryProvider, AbstractKeychainDataStore {

    var cryptor: StoreCryptor? = nil
    var itemQueryProvider: KeyValueStoreItemQueryProvider


    init(queryProvider: KeyValueStoreItemQueryProvider, cryptor: StoreCryptor?) {
        self.itemQueryProvider = queryProvider
        self.cryptor = cryptor
    }

    var rsaKeyPair: SecurityKeyPair? {
        get {
            return self.fetch(itemQueryProvider.RSAKeyPairEncryptedWithMasterKey)
        }
        set {
            var store = self
            _ = store.set(itemQueryProvider.RSAKeyPairEncryptedWithMasterKey, value: newValue)
        }
    }

    func containsRSAKeyPairEntry() -> Bool {
        guard let _: Data = self.fetch(itemQueryProvider.RSAKeyPairEncryptedWithMasterKey) else {
            log(error: "encrypted RSA keypair entry not found")
            return false
        }
        return true
    }

}
