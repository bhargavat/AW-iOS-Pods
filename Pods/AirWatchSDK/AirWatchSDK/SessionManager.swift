//
//  SessionManager.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCrypto

class SessionManager {
    static var serialOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = QualityOfService.userInitiated
        queue.maxConcurrentOperationCount = 1
        queue.name = "com.airwatch.serialSessionQueue"
        return queue
    }()
    

    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var globalSessionStore: GlobalSessionStore
    var rsaKeyPairStore: RSAKeyPairStore

    var localSession: AppSessionInfo? = nil
    var rsaKeyPair: SecurityKeyPair? = nil


    init(itemQueryProvider: KeyValueStoreItemQueryProvider) {
        self.itemQueryProvider =  itemQueryProvider
        self.globalSessionStore = GlobalSessionStore(queryProvider: itemQueryProvider)
        self.rsaKeyPairStore = RSAKeyPairStore(queryProvider: itemQueryProvider, cryptor: nil)
        self.checkRSAKeypairNeedsToBeGenerated()
    }
    
    var hasFinishedGeneratingKeyPair: Bool {
        return SessionManager.serialOperationQueue.operationCount == 0
    }


    func checkRSAKeypairNeedsToBeGenerated() {
        if self.rsaKeyPairStore.containsRSAKeyPairEntry() {
            return
        }
        SessionManager.serialOperationQueue.addOperation { [weak self] in
            self?.generateKeyPair()
        }
    }

    func generateKeyPair() {

        let rsaIdQuery = itemQueryProvider.IdentifierForRSAKeyGen
        //uniqueID = <bundleID>-keyGen
        let uniqueId = rsaIdQuery.group + "-" + rsaIdQuery.key

        do {
            let keyPair = try SecurityKeyPair.generate(2048, identifier: uniqueId, persistent: false)
            guard
                keyPair.areBothKeysAvailable
            else {
                log(error: "rsakeypair generation failure, could not update session")
                return
            }
            self.rsaKeyPair = keyPair
        } catch let error {
            log(error: "generating keyPair failed with error: \(error):")
        }
    }


    public func updateSession(masterKeyCryptor: MasterKeyCryptor, sessionKey: Data, timeOutValue: Double) -> Bool {
        guard timeOutValue >= 0 else {
            log(error: "invalid timeout value")
            return false
        }

        self.rsaKeyPairStore.cryptor = masterKeyCryptor

        let newSession = AppSessionInfo(authetnicatedTimestamp: Date().timeIntervalSince1970,
                                        sessionKey: sessionKey,
                                        validityPeriod: timeOutValue)

        self.localSession = newSession
        if let rsaPair = self.rsaKeyPairStore.rsaKeyPair, let publicKey =  rsaPair.publicKey {
            _ = self.globalSessionStore.addCurrentAppEntry(pubKey: publicKey)
        }

        var updatedGlobalSessionTable = self.globalSessionStore.setGlobalSession(newSessionInfo: newSession)
        if let rsaPair = self.rsaKeyPairStore.rsaKeyPair {
            self.rsaKeyPair = rsaPair
            return updatedGlobalSessionTable
        }

        self.rsaKeyPairStore.rsaKeyPair = nil
        self.globalSessionStore.removeAppEntry()
        log(info: "No Existing RSA Key Pair available in keychain. May need to wait until one to be generated")

        SessionManager.serialOperationQueue.addOperation { [weak self] in
            guard let weakSelf = self else {
                log(error: "sessionManager is deallocated before completing the operation")
                return
            }
            
            if(weakSelf.rsaKeyPair == nil) {
                weakSelf.generateKeyPair()
            }

            guard
                let generatedKeyPair = weakSelf.rsaKeyPair,
                generatedKeyPair.areBothKeysAvailable,
                let publicRSAKey = generatedKeyPair.publicKey
                else {
                    log(error: "rsakeypair generation failure, could not update session")
                    return
            }

            let savedPublicKeyInGlobalSessionTable = weakSelf.globalSessionStore.addCurrentAppEntry(pubKey: publicRSAKey)

            weakSelf.rsaKeyPairStore.rsaKeyPair = generatedKeyPair

            guard savedPublicKeyInGlobalSessionTable && weakSelf.rsaKeyPairStore.containsRSAKeyPairEntry() else {
                log(error: "failed to add RSA public key entry")
                return
            }

            updatedGlobalSessionTable = weakSelf.globalSessionStore.setGlobalSession(newSessionInfo: newSession)
        }

        return updatedGlobalSessionTable
    }

    public func sessionKey() -> Data? {
        guard let currentSession = self.currentSession() else {
            return nil
        }
        log(info: "sessionKey length:" + String(currentSession.sessionKey.count))
        return currentSession.sessionKey
    }
    
    public func isSessionValid() -> Bool {
        guard let currentSession = self.currentSession() else {
            return false
        }
        return currentSession.isSessionValid()
    }
    
    fileprivate func currentSession() -> AppSessionInfo? {
        if let session = self.localSession {
            return session
        }

        log(info: "Local session not found")
        //check privatekey
        guard let privateKey = self.rsaKeyPair?.privateKey else {
            log(info: "no private key found, cannot retrieve session")
            return nil
        }
        guard let currentSession = self.globalSessionStore.retrieveAppSessionInfo(privateKey: privateKey) else {
            log(error: "could not retrieve currentSession")
            return nil
        }
        return currentSession
    }
    
    public func canUpdateCurrentSessionfromGlobalEntry() -> Bool {
        guard self.rsaKeyPair != nil else {
            log(info: "cannot update current session from global table, no keypair generated yet")
            return false
        }
        
        //edge case where we just finish generating but have not added any entry yet
        guard self.globalSessionStore.doesGlobalSessionTableContainCurrentApplicationEntry()
            else {
            log(info: "no current app entry added yet, cannot update session from global table")
            return false
        }

        return true
    }
    
    public func currentGlobalSession() -> AppSessionInfo? {
    
        guard let privateKey = self.rsaKeyPair?.privateKey else {
            log(error: "no private key found, cannot retrieve current global session")
            return nil
        }

        guard let currentSession = self.globalSessionStore.retrieveAppSessionInfo(privateKey: privateKey) else {
            log(info: "currentsession not found in global table")
            return nil
        }
        return currentSession
    }
    
    //clears any previous context related info if any
    public func clearAppEntry() {
        self.globalSessionStore.removeAppEntry()
    }
    
    //clears current session and related information
    public func clearSession() -> Bool {
        self.localSession = nil
        return self.globalSessionStore.clearSessionInfo()
    }
    
    //clears everything
    public func clear() {
        self.globalSessionStore.clearStore()
        self.rsaKeyPair = nil
        self.rsaKeyPairStore.rsaKeyPair = nil
        self.localSession = nil
    }

    //extend without checking validity
    public func extendSession(timeOutValue: Double) -> Bool {
        guard let currentSession = self.currentSession() else {
            log(info: "no current session not found, cannot extend session")
            return false
        }
        let newSession = AppSessionInfo(authetnicatedTimestamp: Date().timeIntervalSince1970,
                                        sessionKey: currentSession.sessionKey,
                                        validityPeriod: timeOutValue)

        return self.globalSessionStore.setGlobalSession(newSessionInfo: newSession)
    }
    
}


