//
//  SDKAccessControlSetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

import AWServices
import AWStorage
import AWPresentation
import AWError

class SDKAccessControlSetupOperation: SDKSetupAsyncOperation {
    fileprivate class StoreMigrationKeys {
        static let ApplicationAuthorization = "_ApplicationAuthorization"
        static let EnrollmentAccount = "_EnrollmentAccount"
        static let AccountCertificate = "_AccountCertificate"
        static let ApplicationKey = "_ApplicationKey"
        static let RememberedUserName = "_RememberedUserName"
    }

    var itemsToMigrate: [String: DataRepresentable] = [:]

    override func startOperation() {
        let application = SDKApplication(context: self.dataStore)
        let isStandAloneApplication = application.isStandAloneApplication
        let ssoEnabled = (self.dataStore.profileRequiredSingleSignOn || self.dataStore.enabledSingleSignOn)
        var shouldUseSharedStores = (ssoEnabled && !isStandAloneApplication)

        if self.dataStore.isNonSharedToSharedMigrationInProgress {
            shouldUseSharedStores = false
        }

        guard let store = self.dataStore as? ApplicationDataStore else {
            log(error: "Can not setup any store other than Appplication Data Store")
            self.markOperationFailed()
            return
        }
        log(info: "Will Setup Access to SSO Store Access: \(shouldUseSharedStores ? "shared" :"non-shared")")
        let currentMode = store.shared
        let futureMode = shouldUseSharedStores
        if currentMode != futureMode {
            self.dataStore.isNonSharedToSharedMigrationInProgress = (currentMode == false && futureMode == true)
            self.itemsToMigrate = self.extractDataForMigration()
            //ISDK-169396 only reset context when future mode is different
            self.dataStore.setContext(shared: shouldUseSharedStores)
        }
        
        self.setupMasterStore(shouldUseSharedStores)
        // Do not mark the operation complete here.
        // It should be the responsibility of setup master data store method.
    }

    fileprivate func setupMasterStore(_ shared: Bool) -> Void {

        guard let store = self.dataStore as? ApplicationDataStore else {
            log(error: "Can not setup any store other than Appplication Data Store")
            self.markOperationFailed()
            return
        }

        let secureDataStore = ApplicationDataStoreLocker(dataStore: store)
        guard secureDataStore.isInitialized else {
            log(debug: "❕❗️Master Key Store was never setup. Setting up with Default Key")
            _ = self.setupMasterKeyStoreWithDefaultKey(secureDataStore)
            self.migrateDataAndFinishOperation(shared)
            return
        }

        if self.unlockMasterStoreWithDefaultKey(secureDataStore) {
            log(debug: "Master Key Store Unlocked With Default Crypt Key")
            self.migrateDataAndFinishOperation(shared)
            return
        } else {
            log(debug: "Unsuccessfully attempted to unlocked master key store with default key")
        }

        //Check global session and if the global session is cleared, lock current application
        // Ask the current session manager to update its local session from global session table
        log(debug: "synchronizing GlobalSession to get global session state(if any)")
        _ = self.dataStore.synchronizeGlobalSession()

        guard secureDataStore.isLocked else {
            log(debug: "Master Key Store already unlocked(must be able to decrypt data).")
            self.migrateDataAndFinishOperation(shared)
            return
        }
        log(debug: "Data Store need to be unlocked")
        log(verbose: "Trying to use the session information")
        if self.unlockMasterStoreWithSessionKey(storeToUnlock:secureDataStore) {
            log(info: "🔓 Data Store Unlocked With Session Key.")
            self.migrateDataAndFinishOperation(shared)
            return
        }
        DispatchQueue.main.async {
            AWController.sharedInstance.delegate?.controllerWillPromptForPasscode?()
        }
        log(debug: "🔐 Session Information did not work to unlock data store")
        let currentAuthenticationMethod = self.dataStore.currentAuthenticationMethod
        
        if currentAuthenticationMethod == AWSDK.AuthenticationMethod.usernamePassword {
            log(debug: "User should enter username/password to complete unlock.")
            self.unlockWithValidationOperaionType(ValidateUserCredentialsToUnlockOperation.self, sharedStore: shared)
        } else if currentAuthenticationMethod == AWSDK.AuthenticationMethod.passcode {
            log(debug: "User should enter passcode to complete unlock.")
            self.unlockWithValidationOperaionType(PasscodeValidationOperation.self, sharedStore: shared)
        } else {
            log(error: "Could not unlock with the default or session key and authentication method is disabled.")
            self.markOperationFailed()
        }
    }
    
    private func unlockWithValidationOperaionType<T: SDKSetupAsyncOperation>(_ type: T.Type, sharedStore: Bool) {

        let operation = T(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        operation.completionBlock = { [weak self, weak operation] in
            if let currentOperation = self,

                let unlockPasscodeOperation  = operation {
                if unlockPasscodeOperation.operationCompletedSuccessfully {
                    log(debug: "🔓 Unlock with \(type) successful")
                    currentOperation.migrateDataAndFinishOperation(sharedStore)
                } else {
                    log(debug: "🔐 Unlock with \(type) failed. still locked")
                    currentOperation.markOperationFailed()
                }
            }
        }

        SDKOperationQueue.workerQueue.addOperation(operation)
    }

    private func migrateDataAndFinishOperation(_ sharedMode: Bool) {
        let newStateOfDataStore = sharedMode ? "Shared": "NonShared"
        let lastStateOfDataStore = self.dataStore.lastDataStoreSetupMode ? "Shared" : "NonShared"
        if newStateOfDataStore == lastStateOfDataStore {
            log(info: "Trying to migrate data when the previous and new state are the same. The current state is \(newStateOfDataStore)")
        } else {
            log(info: "Going to migrate items from old \(lastStateOfDataStore) data store to new \(newStateOfDataStore) data store")
        }

        for (item, value) in self.itemsToMigrate {
            log(info: "Migrating \(item)")
            switch item {

            case StoreMigrationKeys.ApplicationAuthorization:
                log(debug: "Application Identity before migration: \(self.dataStore.applicationIdentity?.authorization?.hmacToken ?? "HMAC Token is nil")")
                if let applicationAuthorization = value as? AuthenticatonInfo {
                    let enrollmentInfo = self.dataStore.enrollmentInformation
                    let identity = Identity(authorization: applicationAuthorization, enrollment: enrollmentInfo)
                    self.dataStore.applicationIdentity = nil
                    self.dataStore.applicationIdentity = identity
                }
                log(debug: "Application Identity after migration: \(self.dataStore.applicationIdentity?.authorization?.hmacToken ?? "HMAC Token is nil")")

            case StoreMigrationKeys.EnrollmentAccount:
                log(debug: "EnrollmentAccount before migration: \(String(describing: self.dataStore.enrollmentAccount))")
                if let enrollmentAccount = value as? AWEnrollmentAccount {
                    self.dataStore.enrollmentAccount = nil
                    self.dataStore.enrollmentAccount = enrollmentAccount
                }
                log(debug: "EnrollmentAccount after migration: \(String(describing: self.dataStore.enrollmentAccount))")

            case StoreMigrationKeys.ApplicationKey:
                log(debug: "applicationKey before migration: \(String(describing: self.dataStore.applicationKey))")

                /* ISDK-169353: We do not migrate if the applicationKeySize is incorrect, this right now is a problem for case when we start in SSO on mode and then delete and reinstall */
                if let applicationKey = value as? Data, applicationKey.hasValidApplicationKeySize {
                    self.dataStore.applicationKey = nil
                    self.dataStore.applicationKey = applicationKey
                }

                log(debug: "ApplicationKey after migration: \(String(describing: self.dataStore.applicationKey))")

                
            case StoreMigrationKeys.RememberedUserName:
                log(debug: "Remembered UserName before migration: \(String(describing: self.dataStore.username))")
                /* ISDK-169769 SE - lock the app and you can authenticate with a different user
                 * We need to remember the username that entered during first launch, that is a SSO OFF case because the profile is not retrieved yet. In case the the profile specify SSO as ON, we need to retain the value of username to prevent it from becoming nil after the profile is applied.
                 */
                if let username = value as? String {
                    self.dataStore.username = nil
                    self.dataStore.username = username
                }
                log(debug: "Remembered UserName after migration: \(String(describing: self.dataStore.username))")
                
            default:
                log(error: "Unknown Information to migrate: \(item)")
            }
        }


        if newStateOfDataStore == "Shared" && lastStateOfDataStore == "NonShared" {
            log(info: "Clearning Key from Non Shared Store due to SSO Status Change")
            //Reset the store key and clear application data store
            let nonSharedStore = ApplicationDataStore()
            nonSharedStore.setContext(shared: false)
            _ = nonSharedStore.resetCurrentKey()
        }

        self.dataStore.lastDataStoreSetupMode = sharedMode
        log(info: "📌📌Completed migration of data to a \(newStateOfDataStore) data store📌📌")
        self.markOperationComplete()
    }

    
    private func unlockMasterStoreWithSessionKey(storeToUnlock: ApplicationDataStoreLocker) -> Bool {

        guard let store = self.dataStore as? ApplicationDataStore else {
            log(error: "Can not setup any store other than Application Data Store")
            self.markOperationFailed()
            return false
        }
        
        guard store.isSessionValid() else {
            log(info: "session is not valid, cannot unlock with sessionKey")
            return false
        }
        guard let sessionKey = store.sessionKey() else {
            log(error: "session key is not avialble, cannot unlock")
            return false
        }
        log(info: "session is valid and session key is available. Trying to unlock with it.")
        if storeToUnlock.unlockDataStore(key: ManagedKey.sessionKey(sessionKey)) {
            return true
        }
        
        log(debug: "Session Key in Store Did not work to unlock the master key store.")
        store.clearSession()
        log(debug: "clearing current session")
        return false
    }

    private var retrievedDefaultCryptKey: Data? = nil;
    private func unlockMasterStoreWithDefaultKey(_ storeToUnlock: ApplicationDataStoreLocker) -> Bool {
        let queryProvider = storeToUnlock.itemQueryProvider
        let defaultKeyProvider = DefaultKeyProvider(itemQueryProvider: queryProvider, datastore: storeToUnlock.securingDatastore.keyStore)

        if let defaultCryptKey = self.retrievedDefaultCryptKey {
            return storeToUnlock.unlockDataStore(key: ManagedKey.cryptKey(defaultCryptKey))
        }

        guard let defaultCryptKey = defaultKeyProvider.defaultCryptKey else {
            log(info: "Can not unlock master store with Empty default crypt key!")
            return false
        }
        self.retrievedDefaultCryptKey = defaultCryptKey
        log(info: "Trying to Unlock with Default Key...")
        return storeToUnlock.unlockDataStore(key: ManagedKey.cryptKey(defaultCryptKey))
    }

    private func setupMasterKeyStoreWithDefaultKey(_ storeToUnlock: ApplicationDataStoreLocker) -> Bool {
        log(error: "Setting up master store with Default Keys.")
        var defaultKeyProvider = DefaultKeyProvider(itemQueryProvider: storeToUnlock.itemQueryProvider, datastore: storeToUnlock.securingDatastore.keyStore)
        var defaultCryptKey = defaultKeyProvider.defaultCryptKey
        var defaultPinData = defaultKeyProvider.defaultPin?.data(using: .utf8)

        if defaultCryptKey == nil || defaultPinData == nil {
            log(info: "Creating Initial Crypt Key")
            _ = defaultKeyProvider.createDefaultPasscode()
            defaultCryptKey = defaultKeyProvider.defaultCryptKey
            defaultPinData = defaultKeyProvider.defaultPin?.data(using: .utf8)
            if let data = defaultPinData {
                log(debug: "Default pin encoded using UTF8 as Data: \(data.hexadecimalString)")
            } else {
                log(debug: "Default pin could not be created")
            }
        }

        guard let cryptKey = defaultCryptKey, let passcodeData = defaultPinData else {
            log(error: "Creating Initial Crypt Key/Passcode Failed.")
            return false
        }


        guard storeToUnlock.resetStore(newCryptKey: cryptKey, passcodeData: passcodeData) else {
            log(error: "Can not use the default crypt key to reset the store. ")
            return false
        }

        log(info: "Data Store Reset to use default crypt key.")
        log(info: "Trying to unlock the master store with fresh default key")
        return unlockMasterStoreWithDefaultKey(storeToUnlock)
    }

    private func extractDataForMigration() -> [String: DataRepresentable] {
        let applicationIdentity = self.dataStore.applicationIdentity
        let enrollmentAccount = self.dataStore.enrollmentAccount
        //Certificate payload also should be trasfered to

        var items: [String: DataRepresentable] = [:]
        if let appKey = self.dataStore.applicationKey, appKey.hasValidApplicationKeySize {
            items[StoreMigrationKeys.ApplicationKey] = appKey
        }
        items[StoreMigrationKeys.ApplicationAuthorization] = applicationIdentity?.authorization
        items[StoreMigrationKeys.EnrollmentAccount] = enrollmentAccount
        
        if let username = self.dataStore.username {
            items[StoreMigrationKeys.RememberedUserName] = username
        }

        return items
    }
}
