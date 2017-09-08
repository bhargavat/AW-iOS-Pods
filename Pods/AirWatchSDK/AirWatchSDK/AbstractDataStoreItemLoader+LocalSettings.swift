//
//  Abstct.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWServices
import AWLog

extension AbstractDataStoreItemLoader {
    
    func getLocalStoreValue<DR: DataRepresentable>(_ key: String) -> DR? {
        return self.localSettingsStore.get(key)
    }
    
    mutating func setLocalStoreValue<DR: DataRepresentable>(_ key: String, value: DR?) -> Bool {
        return self.localSettingsStore.set(key, value: value)
    }

    var enabledSingleSignOn: Bool {
        get {
            let passcodeMode: Bool? = self.getLocalStoreValue("AWSSOStatus")
            return passcodeMode ?? false
        }

        set {
            _ = self.setLocalStoreValue("AWSSOStatus", value: newValue)
        }
    }

    var isNonSharedToSharedMigrationInProgress: Bool {
        get {
            let migrationInProgress: Bool? = self.getLocalStoreValue("AWIsNonSharedToSharedMigrationInProgress")
            return migrationInProgress ?? false
        }

        set {
            _ = self.setLocalStoreValue("AWIsNonSharedToSharedMigrationInProgress", value: newValue)
        }
    }

    var latestAPNSToken: String? {
        get {
            let existingToken: String? = self.getLocalStoreValue("AWSDKDeviceAPNSToken")
            return existingToken
        }
        set {
            _ = self.setLocalStoreValue("AWSDKDeviceAPNSToken", value: newValue)
        }
    }

    var lastDataStoreSetupMode: Bool {
        get {
            guard
                let currentDataStoreMode: Bool = self.getLocalStoreValue("CurrentDataStoreMode")else {
                    return false
            }
            return  currentDataStoreMode
        }
        set {
            _ = self.setLocalStoreValue("CurrentDataStoreMode", value: newValue)
        }
    }
    
    var datastoreVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: "kAWDatastoreVersion") 
        }
        set {
            UserDefaults.standard.set(newValue, forKey:  "kAWDatastoreVersion")
            UserDefaults.standard.synchronize()
        }
    }
    
    var appRegistered: Bool {
        get { return self.getLocalStoreValue("ApplicationRegistered") ?? false }
        set { _ = self.setLocalStoreValue("ApplicationRegistered", value: newValue) }
    }
    
    ///This will be saved to both local store and to non-shared keychain
    var onboardedUser: String? {
        mutating get {
            let valueFromLocalStorage: String? = self.getLocalStoreValue("ApplicationOnBoardedUser")
            let valueFromNonSharedkeychain: String? = self.SSOStore.fetch(itemQueryProvider.OnboardedUser)
            if valueFromLocalStorage == valueFromNonSharedkeychain {
                return valueFromLocalStorage
            } else {
                log(error: "OnboardedUser: valueFromLocalStorage (\(String(describing: valueFromLocalStorage))) does not match valueFromNonSharedkeychain (\(String(describing: valueFromNonSharedkeychain)))")
                ///set both to nil
                onboardedUser = nil
                return nil
            }
        }
        
        set { ///write to both non-shared keychain and local storage
            _ = self.setLocalStoreValue("ApplicationOnBoardedUser", value: newValue)
            _ = self.SSOStore.set(itemQueryProvider.OnboardedUser, value: newValue)
        }
    }
    
    var loggedOut: Bool {
        get { return self.getLocalStoreValue("UserLoggedOut") ?? false }
        set { _ = self.setLocalStoreValue("UserLoggedOut", value: newValue) }
    }
    
    var identity: NSDictionary? {
        get {
            return self.masterDataStore.fetch(itemQueryProvider.IAuthClientCertStoreQuery)
        }
        set {
            _ = self.masterDataStore.set(itemQueryProvider.IAuthClientCertStoreQuery, value: newValue)
        }
    }
    
    var userIdentifier: Int {
        return self.enrollmentAccount?.identifier ?? -1
    }
    
    var lastAppliedSDKProfileIdentifier: String? {
        get { return self.getLocalStoreValue("LatestProfileApplied") }
        set { _ = self.setLocalStoreValue("LatestProfileApplied", value: newValue) }
    }
    
    // TODO: Setup certificate Payload
    var certificatePayload: DataRepresentable? {
        get { return nil }
        set { }
    }
    
    // TODO: Setup SSL Trust public Keys
    var SSLTrustPublicKeys: [String: [String]]? {
        get {
            if let pinnedDict: NSDictionary = self.pinnedPublicKeysStore.get("PinnedPublicKeys") {
                return pinnedDict as? [String: [String]]
            }
            return nil
        }
        set {
            var dict: NSDictionary? = nil
            if let value = newValue {
                dict = (value as NSDictionary)
            }
            
            self.pinnedPublicKeysStore.set("PinnedPublicKeys", value: dict)
        }
    }
    
    // TODO: Setup the DateStamp storage for last SSL Trust Pins fetch
    var timeOfLastSSLTrustKeyFetch: Date? {
        get {
            if let lastFetched: Date = self.pinnedPublicKeysStore.get("TimeLastFetched") {
                return lastFetched as Date
            }
            return nil
        }
        set {
            var date: Date? = nil
            if let value = newValue {
                date = (value as Date)
            }
            
            self.pinnedPublicKeysStore.set("TimeLastFetched", value: date)
        }
    }
    
    var currentLogLevel: AWLogLevel {
        get {
            let storedLevel: UInt? = self.getLocalStoreValue("AWLogLevelSettingsKey")
            if let level = storedLevel {
                return AWLogLevel(rawValue: level) ?? AWLogLevel.info
            }
            return AWLogLevel.info
        }
        set { _ = self.setLocalStoreValue("AWLogLevelSettingsKey", value: newValue.rawValue) }
    }

    var commandLogLevel: AWLogLevel {
        get {
            let storedLevel: UInt? = self.getLocalStoreValue("AWLogLevelCommandKey")
            if let level = storedLevel {
                return AWLogLevel(rawValue: level) ?? AWLogLevel.info
            }
            return AWLogLevel.info
        }
        set { _ = self.setLocalStoreValue("AWLogLevelCommandKey", value: newValue.rawValue) }
    }
    
    var uploadLogTimeStamp: Date? {
        get { return self.getLocalStoreValue("logTimeStamp") }
        set { _ = self.setLocalStoreValue("logTimeStamp", value: newValue) }
    }
    
    var shouldSendLogsOnlyOnWifi: Bool {
        get { return self.getLocalStoreValue("AWLogSendOverWifiOnlySettingsKey") ?? false }
        set { _ = self.setLocalStoreValue("AWLogSendOverWifiOnlySettingsKey", value: newValue) }
    }

    var lastVerifiedOneTimeToken: String? {
        get {
            return self.getLocalStoreValue(KeyValueStoreItemKeyType.LastVerifiedOneTimeToken.rawValue)
        }
        set {
            _ = self.setLocalStoreValue(KeyValueStoreItemKeyType.LastVerifiedOneTimeToken.rawValue, value: newValue)
        }
    }

    var applicationPreviouslyLaunched: Bool {
        //😕 Application had launched and that's it. 😕
        let defaults = UserDefaults.standard
        let currentValue = defaults.bool(forKey: "ApplicationPreviouslyLaunched")
        if currentValue == false {
            log(info: "First Time Launch of the application. Setting application as launched to use from now on...")
            defaults.set(true, forKey: "ApplicationPreviouslyLaunched")
            defaults.synchronize()
        }
        log(info: "Returning is application previously launched: \(currentValue)")
        return currentValue
    }
}
