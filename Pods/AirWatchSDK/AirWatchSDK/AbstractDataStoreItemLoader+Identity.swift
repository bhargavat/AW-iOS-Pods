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

extension AbstractDataStoreItemLoader {

    fileprivate var applicationAuthorization: AuthenticatonInfo? {
        get {
            var dataStore = self
            let query = itemQueryProvider.NonSharedAppIdentityAuthorizationInformation
            var authInfo: AuthenticatonInfo? = self.masterDataStore.fetch(query)
            
            if authInfo == nil, let legacyQuery = query.LegacyItem {
                authInfo = self.masterDataStore.fetch(legacyQuery)
            }
            
            guard let appAuthorization = authInfo, appAuthorization.hmacToken != nil else {
                return nil
            }
            
            if appAuthorization.authorizationGroup == nil || appAuthorization.authorizationGroup?.characters.count == 0 {
                appAuthorization.authorizationGroup = Bundle.main.bundleIdentifier ??
                    KeyValueStoreItemStoreType.NonShared.rawValue
                _ = dataStore.masterDataStore.set(itemQueryProvider.NonSharedAppIdentityAuthorizationInformation, value: appAuthorization)
            }
            return appAuthorization
        }

        set {
            let currentAuthrorization = self.applicationAuthorization
            _ = self.masterDataStore.set(itemQueryProvider.NonSharedAppIdentityAuthorizationInformation, value: newValue)
            DataChangeNotification.HMACSaved.post()
            if currentAuthrorization?.hmacToken != newValue?.hmacToken {
                DataChangeNotification.HMACChanged.post()
            }
        }
    }

    fileprivate var groupAuthorization: AuthenticatonInfo? {
        get {
            // Try first with the value shared in un-enrypted form.

            let latestAuthInfo: AuthenticatonInfo? = self.commonDataStore.fetch(itemQueryProvider.CommonIdentityAuthenticationInformation)
            let latestAuthSavedDate = self.commonDataStore.getlastUpdatedTimestamp(itemQueryProvider.CommonIdentityAuthenticationInformation.group, key: itemQueryProvider.CommonIdentityAuthenticationInformation.key) ?? TimeInterval(0)

            let legacyAuthSavedDate = self.commonDataStore.getlastUpdatedTimestamp(itemQueryProvider.LegacyCommonIdentityAuthenticationInformation.group, key: itemQueryProvider.LegacyCommonIdentityAuthenticationInformation.key) ?? TimeInterval(0)

            if latestAuthSavedDate > legacyAuthSavedDate {
                return latestAuthInfo
            }

            if let authInfo: AuthenticatonInfo = self.masterDataStore.fetch(itemQueryProvider.LegacyCommonIdentityAuthenticationInformation) {
                return authInfo
            }
            return nil
        }
        set {
            _ = self.masterDataStore.set(itemQueryProvider.LegacyCommonIdentityAuthenticationInformation, value: newValue)
            _ = self.commonDataStore.set(itemQueryProvider.CommonIdentityAuthenticationInformation, value: newValue)
            self.commonAuthenticationGroup = newValue?.authorizationGroup
        }
    }

    public var commonIdentity: Identity? {
        get {
            return Identity(authorization: self.groupAuthorization, enrollment: self.enrollmentInformation)
        }
        set {
            self.groupAuthorization = newValue?.authorization
            self.enrollmentInformation = newValue?.enrollment
        }
    }

    public var applicationIdentity: Identity? {
        get {
            return Identity(authorization: self.applicationAuthorization, enrollment: self.enrollmentInformation)
        }
        set {
            self.applicationAuthorization = newValue?.authorization
            // Never Touch enrollment information as part of the application identity.
            //self.enrollmentInformation = newValue?.enrollment
        }
    }
    
    var commonAuthenticationGroup: String? {
        get {
            return self.commonDataStore.fetch(itemQueryProvider.CommonAuthenticationGroup)
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.CommonAuthenticationGroup, value: newValue)
        }
    }
}
