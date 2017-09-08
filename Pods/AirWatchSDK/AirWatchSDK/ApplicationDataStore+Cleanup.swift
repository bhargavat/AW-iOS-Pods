//
//  SDKContext.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWPresentation
import AWStorage
import AWTunnel
import AWLog

extension ApplicationDataStore {

    //clear everything related to AirWatch in the current cluster (keychain sharing set of application)
    static func wipeAirWatchData()  {
        log(error: "Wiping all AirWatch Data")
        
        var dataStore = ApplicationDataStore()
        dataStore.setContext(shared: true)
        dataStore.wipeApplicationData()
        
        dataStore.setContext(shared: false)
        dataStore.wipeApplicationData()
        dataStore.shouldReportUnenrollment = false
    }
    /// This method will clear all the settings that SDK use to perform it's duties. It will also
    /// clear settings stored in local databases as well. This is a destruction operation and
    /// wiped data is completely lost and irrecoverable.
    func wipeApplicationData() {
        log(error: "Wiping Application Data")
        
        clearEnrollment()
        clearIdentity()
        clearSecuritySettings()
        clearSSLPinningSettings()
        clearApplicationKeys()
        clearUserIdentity()
        wipeSettings()
        wipeBranding()
        wipeSecureChannel()
        wipeTunnelStorage()
    }
    
    func wipeThirdPartyApplicationData() {
        wipeApplicationData()
        log(error: "Clearing enrollment information")
    }
    
    func resetPreviousUserApplicationSettings() -> Bool {
        var store = self
        if self.shared == false {
            store.identity = nil
            //we need to preserve application identity, we cannot directly reset store here
            if let cryptor = self.masterDataStore.cryptor,
                let masterKeyCryptor = cryptor as? MasterKeyCryptor {
                 _ = store.removePasscode(key: masterKeyCryptor.decryptionKey)
            }
            else {
                log(error: "could not get current key to reset store.")
                _ = store.resetCurrentKey()
            }
        }
        
        clearApplicationKeys()
        clearSSLPinningSettings()
        wipeSettings()
        wipeBranding()
        wipeSecureChannel()
        wipeTunnelStorage()
        return true
    }

    
    fileprivate func clearEnrollment() {
        var dataStore = self
        let enrollmentInfo = dataStore.enrollmentInformation
        enrollmentInfo?.lastKnownEnrollmentStatus = .unknown
        dataStore.enrollmentInformation = enrollmentInfo
        dataStore.consoleVersion = nil
    }

    fileprivate func clearIdentity() {
        var dataStore = self
        if dataStore.profileRequiredSingleSignOn {
            dataStore.commonIdentity?.authorization = nil
        }
        
        dataStore.identity = nil;
        dataStore.appRegistered = false
        dataStore.onboardedUser = nil
        dataStore.applicationIdentity = nil
        dataStore.loggedOut = true
        dataStore.isApplicationInStandaloneMode = false
    }

    fileprivate func clearSecuritySettings() {
        var dataStore = self
        
        if dataStore.shared {
            dataStore.clearGlobalSession()
        }
        dataStore.clearPreviousSession()
        dataStore.enabledSingleSignOn = false
        dataStore.masterDataStore.cryptor = nil
        dataStore.currentAuthenticationMethod = AWSDK.AuthenticationMethod.none
        dataStore.isPasscodeSet = false
        dataStore.currentPasscodeSetDate = nil
        dataStore.passcodeHistory = nil
        dataStore.failedPasscodeUnlockAttempts = 0
        dataStore.currentBiometricMethod = AWSDK.BiometricMethod.none
        dataStore.isTouchIDConfigured = false
        dataStore.appliedAuthenticationPayloadIdentifier = nil
        dataStore.lastAppliedSDKProfileIdentifier = nil
        dataStore.appliedAuthenticationPayload = nil
        dataStore.lockType = .unknown
        _ = dataStore.resetCurrentKey()
    }

    fileprivate func clearSSLPinningSettings() {
        var dataStore = self
        dataStore.SSLTrustPublicKeys = nil
    }

    fileprivate func clearApplicationKeys() {
        var dataStore = self
        dataStore.applicationKey = nil
        dataStore.sharedContainerKey = nil
        _ = EncryptedStoreKeyProvider.clearKey()
    }

    fileprivate func clearUserIdentity() {
        var dataStore = self
        dataStore.identity = nil
        dataStore.username = nil
        dataStore.enrollmentAccount = nil
        dataStore.certificatePayload = nil
        dataStore.currentUserInformation = nil
        dataStore.enrolledUserEmailAddress = nil
    }

    fileprivate func wipeSettings() {
        self.wipeAllStoreData()
    }

    fileprivate func wipeBranding() {
        AWBrandingManager.sharedInstance.wipeData()
    }

    fileprivate func wipeSecureChannel() {
        self.secureChannelConfigurationManager?.clearAll()
    }

    fileprivate func wipeTunnelStorage() {
        AWTunnelService.sharedInstance.wipeStorage()
    }
}
