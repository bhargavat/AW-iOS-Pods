//
//  AllDataStores.swift
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
import AWServices


let AWSettingsDatabase = SQLiteDatabase(sqliteFilePath: SQLiteDatabase.documentsLocalSettingsFilepath("AWSettings.sqlite"))

open class ApplicationDataStore: SDKContext, AbstractDataStoreItemLoader {
    open internal(set) var shared: Bool = false
    internal var lockType: LockType = LockType.unknown
    
    var itemQueryProvider: KeyValueStoreItemQueryProvider = .nonSharedItem
    var sessionManager: SessionManager? = nil

    var commonDataStore: AbstractKeyValueStore = KeychainDataStore()
    var keyStore: AbstractKeyValueStore = KeychainDataStore()
    var SSOStore: AbstractKeyValueStore = KeychainDataStore()
    var vendorStore: AbstractKeyValueStore = KeychainDataStore()
    var masterDataStore: AbstractKeyValueStore = KeychainDataStore()
    var consoleVersion: ConsoleVersion? = nil
    
    var localSettingsStore: LocalSettingsDataStore = AWSettingsDatabase.getDatastore("Settings")
    var profilesStore: LocalSettingsDataStore = AWSettingsDatabase.getDatastore("Profiles")
    var pinnedPublicKeysStore: LocalSettingsDataStore = AWSettingsDatabase.getDatastore("PinnedPublicKeys")

    public init() {
        // If this migration step is placed elsewhere then when this object is instantiated in AWController the performFreshInstallChecks will clear data
        let dataMigrationHelper = SDKDataMigration(context: self)
        dataMigrationHelper.performMigration()
        self.performFreshInstallChecks()
        self.shared = self.lastDataStoreSetupMode
        self.setContext(shared: shared)
    }

    private func performFreshInstallChecks() {
        
        var store = self
        if store.applicationPreviouslyLaunched == false {
            // Clear any lingering sessions. This should clear only application session as by the time we detect that
            // SSO is on. this should have been run once for initial store setup.
            store.clearPreviousSession()
            _ = store.resetCurrentKey()
            store.applicationIdentity = nil
            store.appRegistered = false
            store.loggedOut = true

            store.username = nil
            store.enrollmentAccount = nil

            store.onboardedUser = nil
            store.currentPasscodeSetDate = nil
            store.passcodeHistory = nil
            store.needToEscrowPasscode = false
            store.enabledSingleSignOn = false
            store.lockType = .unknown
            store.consoleVersion = nil

            store.applicationKey = nil
            //Do not need to delete any databases from documents directoty at this moment as this would be a fresh install.
            //TODO: This should be handled properly for extensions and app groups.
        }

    }

    func setContext(shared: Bool) {

        log(info: "Warming up Data Store in Shared Mode: \(shared)")

        self.shared = shared
        self.itemQueryProvider = shared ? .sharedItem : .nonSharedItem
        self.commonDataStore = KeychainDataStore()

        self.SSOStore = KeychainDataStore()
        self.vendorStore = KeychainDataStore()
        self.masterDataStore = KeychainDataStore()
        self.keyStore = KeychainDataStore()

        self.vendorStore.cryptor = VendorKeyCryptor()

        //Check if we ever have used the store and initilize with default key if not
        let secureStore = ApplicationDataStoreLocker(dataStore: self)
        if secureStore.isInitialized == false {
            _ = self.resetCurrentKey()
        }


        if shared != lastDataStoreSetupMode {
            log(info: "clearing previous session since we are changing status")
            self.clearPreviousSession()
        }

        if self.sessionManager == nil {
            self.sessionManager = SessionManager(itemQueryProvider: itemQueryProvider)
        }
    }

    fileprivate var _profiles: [Profile]? = nil
    var profiles: [Profile] {
        if let profiles = _profiles {
            return profiles
        }
        
        let loadedProfiles = self.loadProfiles()
        if loadedProfiles.isEmpty == false {
            _profiles = loadedProfiles
        }
        
        return _profiles ?? []
    }

    func saveProfile(_ profile: Profile) -> Bool {
        _profiles = nil
        var datastore = self
        return datastore.storeProfile(profile)
    }

    func wipeAllProfiles() -> Bool {
        var datastore = self
        for profile in profiles {
            let profileType = profile.profileType.StringValue
            _ = datastore.removeProfile(profileType)
        }
        _profiles = nil
        return true
    }
    func wipeAllStoreData() {
        localSettingsStore.clear()
        profilesStore.clear()
        pinnedPublicKeysStore.clear()
    }

    func loadProfile(_ profileType: String) -> Profile? {
        return self.fetchProfile(profileType)
    }
    
}
