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
import AWLocalization


extension AWError.SDK.Security {
    enum TouchIDAuthentication {
        enum Setup: AWSDKErrorType {
            case requiredUnlockedDataStoreToSetupTouchID
            case touchIDKeySetupFailed
        }
    }
}

protocol AbstractStorageSecurityProvider: DataStoreItemQueryProvider {

    mutating func isValid(passcode: String) -> Bool

    mutating func createPasscode(newPasscode: String) -> Bool
    mutating func changePasscode(oldPasscode: String, newPasscode: String) -> Bool


    mutating func isCurrentPasscodeCompliant(payload: AuthenticationPayload) -> Bool

    mutating func enableTouchIDAuthentication(completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) -> Void
    mutating func authenticateWithTouchID(completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) -> Void

    mutating func removePasscode(key: ManagedKey) -> Bool
    mutating func resetCurrentKey() -> Bool
}

extension ApplicationDataStore: AbstractStorageSecurityProvider {

    // When locking the current store we need to have a lockType to define  
    func lockCurrentStores(lockType: LockType) -> Bool {
        let unlockDataStore = ApplicationDataStoreLocker(dataStore: self)
        self.clearSession()
        if unlockDataStore.lockDataStore() {
            DispatchQueue.main.async {
                AWController.sharedInstance.delegate?.controllerDidLockDataAccess?()
            }
            self.lockType = lockType
#if sdk_mixpanel_data_collection_enabled
            SDKMixpanelDataCollectionService.sharedInstance?.track(event: SDKLifeCycleEvent.locked(lockType))
#endif
            return true
        }
        return false
    }
    
    func isUsingDefaultPasscode() -> Bool {

        let unlockDataStore = ApplicationDataStoreLocker(dataStore: self)
        let defaultKeyProvider = DefaultKeyProvider(itemQueryProvider: unlockDataStore.itemQueryProvider, datastore: unlockDataStore.securingDatastore.keyStore)
        guard let defaultCryptKey = defaultKeyProvider.defaultCryptKey else {
            log(error: "Store was not initialized before asking what kind of passcode it is using.")
            return false
        }
        return unlockDataStore.unlockDataStore(key: ManagedKey.cryptKey(defaultCryptKey))
        
    }

    /**
     This function will evaluate the passcode status based off of the profile and if the passcode saved meets the requirements of the profile. If you attempt to evaluate a payload that sets username and password or if the authentication method is disabled, false will be returned.
     @return If passcode is set, then true or false will be returned if it is successful. If username and password, or disable is specified in payload, then false will be returned
     */
    func isCurrentPasscodeCompliant(payload: AuthenticationPayload) -> Bool {
        
        log(debug: "Is the payload compliant with the saved passcode on device?")
        let authenticationPolicyManager = AuthenticationPolicyHelper(payload: payload)
        let currentPasscodeData: Data? = self.masterDataStore.fetch(self.itemQueryProvider.EncryptedPasscode)

        // If authentication type is required by the payload and passcode is not set, then we return that the current passcode is not compliant
        if self.isPasscodeSet == false && authenticationPolicyManager.requiresAuthentication == true {
            log(error: "Passcode is not set and an authentication type is required by the current policy.")
            return false
        }

        guard let passcodeData = currentPasscodeData else {
            log(error: "Passcode is required by current policy but is not set")
            log(debug: "The passcode that was fetched from the master data store returned nil")
            return false
        }

        guard let passcodeString = String(data: passcodeData, encoding: String.Encoding.utf8) else {
            log(info: "")
            return true
        }

        // If authenticationPolicyManager passcode is set to UsernamePassword, alert through console that the passcode cannot be checked because Username and Password is specified in the payload
        if authenticationPolicyManager.requiresUsernamePasswordAuthentication {
            log(debug: "Cannot verify if passcode is compliant if payload specifies UsernamePassword.")
            return false
        }

        if authenticationPolicyManager.requiresPasscodeAuthentication {
            // If authenticationPolicyManager passcode is set to Passcode, check that it is valid
            let passcodeComplianceDetector = PasscodeCompliance(dataStore: self)
            passcodeComplianceDetector.checkPasscodeAge = true

            let passcodeComplianceStatus = passcodeComplianceDetector.passcodeCompliesWithRestrictions(passcodeString)

            if passcodeComplianceStatus.compliant {
                log(debug: "The passcode saved passes the restrictions emposed by the payload")
                return true
            }

            log(debug: "The passcode saved does not pass the restrictions emposed by the payload")
            log(debug: passcodeComplianceStatus.complianceMessage)
            return false
        }

        // Payload is set to no authentication, therefore we need to check if the default passcode is set
        if self.isUsingDefaultPasscode() {
            log(debug: "The default passcode is compliant")
            return true
        }

        log(debug: "The default passcode is not compliant")
        return false
    }

    func enableTouchIDAuthentication(completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {

        let storeToUnlock = ApplicationDataStoreLocker(dataStore: self)
        //Just make sure the store is unlocked.
        guard storeToUnlock.isLocked == false else {
            log(error: "Data Store must have been unlocked to enable Touch ID Authentication")
            completion(false, AWError.SDK.Security.TouchIDAuthentication.Setup.requiredUnlockedDataStoreToSetupTouchID.error)
            return
        }

        let task = beginBackgroundRunningTask()
        struct SecureEnclaveStorageHelper: AbstractSecureEnclaveStore {
            var cryptor: StoreCryptor? = nil
        }

        guard
            let touchIdKey = storeToUnlock.setupTouchIDKey()
            else {
                log(error: "Failed to Setup Touch ID Key.")
                completion(false, AWError.SDK.Security.TouchIDAuthentication.Setup.touchIDKeySetupFailed.error)
                return
        }
        
        var secureEnclaveStore = SecureEnclaveStorageHelper()
        let secureEnclaveQuery: KeyValueStoreItemQuery = self.itemQueryProvider.SecureEnclaveQuery
        //save to secureEnclave
        secureEnclaveStore.set(secureEnclaveQuery.group, key: secureEnclaveQuery.key, value:touchIdKey) { (success: Bool, error: NSError?) in
            if (success) {
                log(info: "touchId key saved in SecureEnclave successfully")
            } else {
                log(error: "Saving touchId key to secureEnclave failed with error: \(String(describing: error))")
            }
            completion(success, error)
            self.finishTask(task)
        }
    }

    func authenticateWithTouchID(completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {

        struct SecureEnclaveStorageHelper: AbstractSecureEnclaveStore {
            var cryptor: StoreCryptor? = nil
        }

        let secureEnclaveStore = SecureEnclaveStorageHelper()
        let secureEnclaveQuery: KeyValueStoreItemQuery = self.itemQueryProvider.SecureEnclaveQuery

        secureEnclaveStore.get(secureEnclaveQuery.group, key: secureEnclaveQuery.key) { (success: Bool, data: Data?, error: NSError?) in
            guard success else {
                log(error: "fetching cryptkey from secureEnclave failed with error: \(String(describing: error))")
                completion(false, error)
                return
            }

            log(info: "fetched crypt key from secureEnclaveSuccessfully with cryptkeyLength length \(data?.count ?? 0)")
            // TODO: What if data is empty?
            guard let touchIDkey = data else {
                log(error: "Data passed is nil")
                completion(false, error)
                return
            }

            //Validate provided Key and check if the provided key is Valid
            let touchIDKey = ManagedKey.touchIDKey(touchIDkey)
            let storeToUnlock = ApplicationDataStoreLocker(dataStore: self)
            guard storeToUnlock.unlockDataStore(key: touchIDKey) else {
                log(error: "⚠️⚠️⚠️Application data store can not be unlocked with Touch ID Key retrieved using finger print. Completing without creating session.⚠️⚠️⚠️")
                completion(false, error)
                return
            }

            //We should create the Touch ID Cryptor
            self.startNewSession()
            completion(success, error)
        }
    }

    func removePasscode(key: ManagedKey) -> Bool {
        let task = beginBackgroundRunningTask()
        log(error: "Trying to drop current Crypt key.")
        let storeToUnlock = ApplicationDataStoreLocker(dataStore: self)
        guard storeToUnlock.unlockDataStore(key: key) else {
            log(error: "Application data store can not be unlocked with the given key\(key). returning false")
            return false
        }

        var defaultKeyProvider = DefaultKeyProvider(itemQueryProvider: storeToUnlock.itemQueryProvider, datastore: storeToUnlock.securingDatastore.keyStore)

        log(info: "Creating Default passcode")
        _ = defaultKeyProvider.createCryptKeySalt()
        defaultKeyProvider.createDefaultPasscode()
        let defaultCryptKey = defaultKeyProvider.defaultCryptKey
        let defaultPinData = defaultKeyProvider.defaultPin?.data(using: String.Encoding.utf8)

        guard let cryptKey = defaultCryptKey, let passcodeData = defaultPinData else {
            log(error: "Creating Initial Crypt Key/Passcode Failed.")
            return false
        }


        guard storeToUnlock.changeKey(key: key, newCryptKey: cryptKey, passcodeData: passcodeData) else {
            log(error: "🤔 Can not change key from old crypt key to new crypt key. We have regenerated salt. It will never work again with user pin.")
            log(error: "We have to reset it for the user. Verification was successful but change not? 😤")
            return false
        }

        log(info: "Data Store Successfully dropped current key. Now the store is using default key(⚠️) always. ")
        self.resetDataStoreToDefault()
        finishTask(task)

        return storeToUnlock.unlockDataStore(key: .cryptKey(cryptKey))
    }

    //sets the default pin  and return the crypt key(from default pin)
    fileprivate func resetDataStoreToDefault() -> Void {

        var dataStore = self
        dataStore.isPasscodeSet = false
        dataStore.newSDKPasscodeSetDate = nil
        dataStore.currentPasscodeSetDate = nil
        dataStore.failedPasscodeUnlockAttempts = 0
        dataStore.currentAuthenticationMethod = AWSDK.AuthenticationMethod.none
        dataStore.needToEscrowPasscode = false
        dataStore.currentBiometricMethod = AWSDK.BiometricMethod.none
        self.clearSession()
        
    }

    internal func resetCurrentKey() -> Bool {
        let task = beginBackgroundRunningTask()
        log(error: "Setting up master store with Default Keys.")
        let storeToUnlock = ApplicationDataStoreLocker(dataStore: self)
        storeToUnlock.keyMaker.clearMasterKeyMaker()    
        var defaultKeyProvider = DefaultKeyProvider(itemQueryProvider: storeToUnlock.itemQueryProvider, datastore: storeToUnlock.securingDatastore.keyStore)

        log(info: "Creating Initial Crypt Key")
        _ = defaultKeyProvider.createCryptKeySalt()
        defaultKeyProvider.createDefaultPasscode()
        let defaultCryptKey = defaultKeyProvider.defaultCryptKey
        let defaultPinData = defaultKeyProvider.defaultPin?.data(using: String.Encoding.utf8)

        guard let cryptKey = defaultCryptKey, let passcodeData = defaultPinData else {
            log(error: "Creating Initial Crypt Key/Passcode Failed.")
            return false
        }


        guard storeToUnlock.resetStore(newCryptKey: cryptKey, passcodeData: passcodeData) else {
            log(error: "Can not use the default crypt key to reset the store. ")
            return false
        }

        log(info: "Data Store Reset to use default crypt key.")
        var dataStore = self
        dataStore.isPasscodeSet = false
        dataStore.newSDKPasscodeSetDate = nil
        dataStore.currentPasscodeSetDate = nil
        dataStore.failedPasscodeUnlockAttempts = 0
        dataStore.currentAuthenticationMethod = AWSDK.AuthenticationMethod.none
        dataStore.needToEscrowPasscode = false
        dataStore.currentBiometricMethod = AWSDK.BiometricMethod.none
        self.clearSession()
        
        log(info: "Trying to unlock the master store with fresh default key")
        finishTask(task)
        return storeToUnlock.unlockDataStore(key: .cryptKey(cryptKey))
    }

    fileprivate func beginBackgroundRunningTask() -> UIBackgroundTaskIdentifier {
        let application = UIApplication.shared
        var bgTask: UIBackgroundTaskIdentifier = 0
        bgTask = application.beginBackgroundTask (expirationHandler: {[weak application] in
            application?.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        })
        return bgTask
    }

    fileprivate func finishTask(_ task: UIBackgroundTaskIdentifier) {
        UIApplication.shared.endBackgroundTask(task)
    }

    func isValid(passcode: String) -> Bool {
        let task = beginBackgroundRunningTask()
        let cryptKeyProvider = CryptKeyProvider(itemQueryProvider: self.itemQueryProvider, datastore: self.keyStore)

        guard let cryptKey = cryptKeyProvider.cryptKeyWithPin(passcode) else {
            log(error: "Can not retrieve CryptKey with the provided Pin")
            finishTask(task)
            return false
        }
        let dataStoreLocker = ApplicationDataStoreLocker(dataStore: self)
        guard dataStoreLocker.unlockDataStore(key: .cryptKey(cryptKey)) else {
            log(error: "Invalid Key entered by used. Counting towards failed attempts.")
            var currentFailedAttempts = self.failedPasscodeUnlockAttempts
            currentFailedAttempts += 1
            log(error: "Total failed attempts so far: \(currentFailedAttempts).")
            dataStoreLocker.securingDatastore.failedPasscodeUnlockAttempts = currentFailedAttempts
            finishTask(task)
            return false
        }
        
        self.startNewSession()
        finishTask(task)
        return true
    }

    func changePasscode(oldPasscode: String, newPasscode: String) -> Bool {
        guard self.isValid(passcode: oldPasscode) else {
            log(error: "Given passcode can not be used to change passcode.")
            return false
        }

        let task = beginBackgroundRunningTask()
        
        var cryptKeyProvider = CryptKeyProvider(itemQueryProvider: self.itemQueryProvider, datastore: self.keyStore)
        guard let currentCryptKey = cryptKeyProvider.cryptKeyWithPin(oldPasscode) else {
            log(error: "Can not create crypt key from the given old passcode")
            finishTask(task)
            return false
        }

        log(debug: "☛ Resetting current Crypt Key salt. No going back to unlock with old key. (unless you have escrowed the key)")
        _ = cryptKeyProvider.createCryptKeySalt()
        let dataStoreLocker = ApplicationDataStoreLocker(dataStore: self)
        
        guard let newCryptKey = cryptKeyProvider.cryptKeyWithPin(newPasscode),
            let passcodeData = newPasscode.data(using: String.Encoding.utf8) else {
                log(debug: "(re)generating Crypt Key Salt and associated pin has failed. Now the store is officially useless! 😤")
                finishTask(task)
                return false
        }
        
        let updatePasscodeSucceeded = dataStoreLocker.changeKey(key: .cryptKey(currentCryptKey), newCryptKey: newCryptKey, passcodeData: passcodeData)
        let unlockWithNewPasscode = dataStoreLocker.unlockDataStore(key: .cryptKey(newCryptKey))
        guard updatePasscodeSucceeded, unlockWithNewPasscode else {
            log(debug: "👎 Un-successful at changing passcode")
            finishTask(task)
            return false
        }
        
        self.startNewSession()
        log(debug: "👍 Successfully changed passcode")
        finishTask(task)
        return true
    }

    func createPasscode(newPasscode: String) -> Bool {
        let defaultKeyProvider = DefaultKeyProvider(itemQueryProvider: self.itemQueryProvider, datastore: self.keyStore)
        guard let defaultPin = defaultKeyProvider.defaultPin else {
            log(error: "Default Key/Pin is missing from Storage. Was store ever initialized?")
            return false
        }
        
        return self.changePasscode(oldPasscode: defaultPin, newPasscode: newPasscode)
    }
}
