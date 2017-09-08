//
//  SecurityProvider.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWServices
import AWError
import AWPresentation
import AWStorage
import AWPresentation

protocol AbstractSessionProvider: DataStoreItemQueryProvider {

    mutating func synchronizeGlobalSession() -> Bool
    mutating func lockCurrentStores(lockType: LockType) -> Bool
    mutating func clearSession() -> Void

    mutating func startNewSession() -> Void

    mutating func extendSSOSession() -> Void
    mutating func isSessionValid() -> Bool
    mutating func sessionKey() -> Data?
    mutating func clearPreviousSession() -> Void
    mutating func clearGlobalSession() -> Void
}

extension ApplicationDataStore: AbstractSessionProvider {

    func synchronizeGlobalSession() -> Bool {

        let unlockDataStore = ApplicationDataStoreLocker(dataStore: self)
        //check if global entry exists, update session if it does
        let datastore = self
        guard let sessionManager = datastore.sessionManager else {
            log(error: "sessionManager is not initialized")
            return false
        }
        
        guard sessionManager.hasFinishedGeneratingKeyPair else {
            //we do NOT want to clear the local session here
            log(info: "cannot synchronize with global session as keypair generation is in progress")
            return false
        }

        guard sessionManager.canUpdateCurrentSessionfromGlobalEntry() else {
            
            sessionManager.localSession = nil
            _ = unlockDataStore.lockDataStore()
            return false
        }

        guard let currentGlobalSession = sessionManager.currentGlobalSession() else {
            log(info: "global session not found, clearing current session")
            sessionManager.localSession = nil
            _ = unlockDataStore.lockDataStore()
            return true
        }

        //change session key, sessionKey from global table should be able to unlock dataStore
        guard currentGlobalSession.isSessionValid() else {
            log(info: "global session is not valid, clearing local session")
            _ = sessionManager.clearSession()
            sessionManager.localSession = nil
            _ = unlockDataStore.lockDataStore()
            return true
        }

        let isGlobalSessionValid = unlockDataStore.unlockDataStore(key: ManagedKey.sessionKey(currentGlobalSession.sessionKey))
        if  isGlobalSessionValid {
            sessionManager.localSession = currentGlobalSession
            log(info: "sucessfully updated local session from global session")
        } else {
            log(error: "failed to unlock datastore with global session")
        }

        return isGlobalSessionValid
    }

    func startNewSession() -> Void {
        let lockableStore = ApplicationDataStoreLocker(dataStore: self)
        guard
            lockableStore.isLocked == false,
            let cryptor = self.masterDataStore.cryptor as? MasterKeyCryptor
            else {
            log(error: "⚠️⚠️⚠️Store Must be unlocked first to create a new unlocked Session.⚠️⚠️⚠️")
            return
        }

        guard
            let sessionKey = lockableStore.setupSessionKey()
        else {
            log(error: "⚠️⚠️⚠️Failed to setup Session Key, cannot start a new session⚠️⚠️⚠️")
            return
        }

        guard let sessionManager = self.sessionManager else {
            log(error: "⚠️⚠️⚠️ SessionManager is not initialized ⚠️⚠️⚠️")
            return
        }
        let passcodeTimeout = self.SDKProfile?.authenticationPayload?.passcodeTimeout ?? Int.max
        _ = sessionManager.updateSession(masterKeyCryptor: cryptor, sessionKey: sessionKey, timeOutValue: TimeInterval(passcodeTimeout))
    }

    func clearSession() -> Void {
        guard let sessionManager = self.sessionManager else {
            log(error: "⚠️⚠️⚠️ SessionManager is not initialized, cannot clear session ⚠️⚠️⚠️")
            return
        }
        _ = sessionManager.clearSession()

    }

    /*
     * Extending without checking for validity , need to check if validity is required
     * only thing is if session has been updated by some other app, we will be using previous
     * sessionkey from the temp session (if temp session was avalaible with sessionManager)
     */
    func extendSSOSession() -> Void {
        guard let sessionManager = self.sessionManager else {
            log(error: "⚠️⚠️⚠️ SessionManager is not initialized, cannot extend session ⚠️⚠️⚠️")
            return
        }

        let passcodeTimeout = self.SDKProfile?.authenticationPayload?.passcodeTimeout ?? Int.max
        if sessionManager.extendSession(timeOutValue: TimeInterval(passcodeTimeout)) {
            log(info: "successfully extended session")
        }
        else {
            log(error: "error extending session")
        }
    }

    func isSessionValid() -> Bool {
        let datastore = self
        guard let sessionManager = datastore.sessionManager else {
            log(error: "⚠️⚠️⚠️ SessionManager is not initialized, cannot extend session ⚠️⚠️⚠️")
            return false
        }
        return sessionManager.isSessionValid()
    }

    func sessionKey() -> Data? {
        let datastore = self
        guard let sessionManager = datastore.sessionManager else {
            log(error: "⚠️⚠️⚠️ SessionManager is not initialized, cannot provide Session key ⚠️⚠️⚠️")
            return nil
        }
        return sessionManager.sessionKey()
    }

    func clearPreviousSession() -> Void {

        let sharedSessionManager = SessionManager(itemQueryProvider: .sharedItem)
        sharedSessionManager.clearAppEntry()
        
        let applicationSessionManager = SessionManager(itemQueryProvider: .nonSharedItem)
        applicationSessionManager.clear()
        
        self.sessionManager = nil
    }
    
    func clearGlobalSession() -> Void {
        let datastore = self
        guard let sessionManager = datastore.sessionManager else {
            log(error: "⚠️⚠️⚠️ SessionManager is not initialized, cannot clear Global session ⚠️⚠️⚠️")
            return
        }
        sessionManager.clear()
    }
    
    
}
