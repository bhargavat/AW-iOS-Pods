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
import AWServices

extension AbstractDataStoreItemLoader {
    var isApplicationInStandaloneMode: Bool {
        get {
            let standaloneAuthenticated: Bool? = self.localSettingsStore.get("AWAuthenticatedForStandalone")
            return standaloneAuthenticated ?? false
        }

        set {
            self.localSettingsStore.set("AWAuthenticatedForStandalone", value: newValue)
        }
    }

    var isPasscodeSet: Bool {
        get {
            let passcodeSet: Bool? = self.SSOStore.fetch(itemQueryProvider.ProtectedWithPasscode)
            return passcodeSet ?? false
        }

        set {
            _ = self.SSOStore.set(itemQueryProvider.ProtectedWithPasscode, value: newValue)
        }
    }

    var newSDKPasscodeSetDate: Date? { ///This can be removed once we are sure all customers are using at least version 6.0
        get {
            return self.masterDataStore.fetch(itemQueryProvider.NewSDKPasscodeSetDate)
        }
        set {
            _ = self.masterDataStore.set(itemQueryProvider.NewSDKPasscodeSetDate, value: newValue)
        }
    }

    var currentPasscodeSetDate: Date? {
        get {
            return self.masterDataStore.fetch(itemQueryProvider.CurrentPasscodeSetDate)
        }

        set {
            _ = self.masterDataStore.set(itemQueryProvider.CurrentPasscodeSetDate, value: newValue)
            _ = self.masterDataStore.set(itemQueryProvider.NewSDKPasscodeSetDate, value: newValue)///newSDKSetDate should be equal to setDate if SDK 6.0+ was used to set passcode
        }
    }

    var passcodeHistory: [[Data:Data]]? {
        get {
            guard
                let data: Data = self.SSOStore.fetch(itemQueryProvider.PasscodeHistory),
                let mutableArray =  NSKeyedUnarchiver.unarchiveObject(with: data) as? NSMutableArray,
                let swiftArray = Array(mutableArray) as? [[Data: Data]]
            else {
                return nil
            }
            return swiftArray
        }

        set {
            let dataToSave: Data?
            if let array: [[Data:Data]] = newValue {
                dataToSave = NSKeyedArchiver.archivedData(withRootObject: NSMutableArray(array: array))
            } else {
                dataToSave = nil
            }
            _ = self.SSOStore.set(itemQueryProvider.PasscodeHistory, value: dataToSave)
        }
    }

    var failedPasscodeUnlockAttempts: Int {
        get {
            if let data: Data =  self.commonDataStore.fetch(itemQueryProvider.PasscodeFailedAttemps) {
                let ret = data.withUnsafeBytes( { (ptr: UnsafePointer<Int>) -> Int in
                    let ret = ptr.withMemoryRebound(to: Int.self, capacity: 1, { (ptrInt) -> Int in
                        return ptrInt.pointee
                    })
                    return ret
                })
                return ret
            }
            return 0
        }

        set {
            var value = newValue
            let data = Data(bytes: &value, count: MemoryLayout<Int>.size)
            _ = self.commonDataStore.set(itemQueryProvider.PasscodeFailedAttemps, value: data)
        }
    }

    var currentAuthenticationMethod: AWSDK.AuthenticationMethod {
        mutating get {
            let authenticationType = itemQueryProvider.AuthenticationType
            let legacyAuthenticationType = itemQueryProvider.LegacyAuthenticationType

            let savedAuthenticationMethod: AWSDK.AuthenticationMethod? = self.SSOStore.fetch(authenticationType)
            let legacyStoredAuthenticationMethod: AWSDK.AuthenticationMethod? = self.SSOStore.fetch(legacyAuthenticationType)

            // If old authentication type is nil, let's check the new authentication type to see if it exists. If the new value exists, we'll set the old one using the new version, else if the new and old do not exists we set authentication type to .None and save into the legacy location

            if let legacyStoredAuthenticationMethod = legacyStoredAuthenticationMethod,
                savedAuthenticationMethod == nil {
                //Copying current authentication mode from existing Agent/5.9 SDK location to new location.
                _ = self.SSOStore.set(authenticationType, value: legacyStoredAuthenticationMethod)
                return legacyStoredAuthenticationMethod
            }

            if savedAuthenticationMethod != nil &&
                legacyStoredAuthenticationMethod == nil {
                //Technically this situtation should never occur as we write to both locations from new SDK.
                //We do not update the old location as we might have been stopeed suppoting 6.0 working with 5.9.x
            }

            if savedAuthenticationMethod != nil &&
                legacyStoredAuthenticationMethod != nil &&
                legacyStoredAuthenticationMethod != savedAuthenticationMethod {
                // We have an updated authentication type from common location set by pre6.0 application. We need to update the current SDK authentication Type with what ever value set by the pre6.0
                let latestAuthModeSavedDate = self.commonDataStore.getlastUpdatedTimestamp(itemQueryProvider.AuthenticationType.group, key: itemQueryProvider.AuthenticationType.key) ?? TimeInterval(0)

                let legacyAuthModeSavedDate = self.commonDataStore.getlastUpdatedTimestamp(itemQueryProvider.LegacyAuthenticationType.group, key: itemQueryProvider.LegacyAuthenticationType.key) ?? TimeInterval(0)

                if latestAuthModeSavedDate <= legacyAuthModeSavedDate {
                    _ = self.SSOStore.set(authenticationType, value: legacyStoredAuthenticationMethod)
                }
            }

            let currentAuthenticationMethod: AWSDK.AuthenticationMethod? = self.SSOStore.fetch(authenticationType)
            return currentAuthenticationMethod ?? .none
        }

        set {
            // The new key to save authentication type
            let authenticationType = itemQueryProvider.AuthenticationType
            _ = self.SSOStore.set(authenticationType, value: newValue)
            // The legacy location to save authentication type for older versions
            // TODO: Remove the legacy code in the future. The new key was implemented in 6.0
            let legacyAuthenticationType = itemQueryProvider.LegacyAuthenticationType
            _ = self.SSOStore.set(legacyAuthenticationType, value: newValue)
        }
    }

    var currentBiometricMethod: AWSDK.BiometricMethod {
        get {
            let biometricMode: AWSDK.BiometricMethod? = self.SSOStore.fetch(itemQueryProvider.BiometricMethod)
            return biometricMode ?? .none
        }

        set {
            _ = self.SSOStore.set(itemQueryProvider.BiometricMethod, value: newValue)
        }
    }
    var isTouchIDConfigured: Bool {
        get {
            let biometricMode: Bool? = self.SSOStore.fetch(itemQueryProvider.TouchIDConfigured)
            return biometricMode ?? false
        }

        set {
            _ = self.SSOStore.set(itemQueryProvider.TouchIDConfigured, value: newValue)
        }

    }

    var payloadIdentifier: String? {
        get {
            return self.SSOStore.fetch(itemQueryProvider.AuthenticationPayloadIdentifier)
        }
        set {
            _ = self.SSOStore.set(itemQueryProvider.AuthenticationPayloadIdentifier, value: newValue)
        }
    }

    var needToEscrowPasscode: Bool {
        get {
            let escrowed: Bool? = self.SSOStore.fetch(itemQueryProvider.PasscodeEncrowedSuccessfully)
            return escrowed ?? false
        }
        set {
            _ = self.SSOStore.set(itemQueryProvider.PasscodeEncrowedSuccessfully, value: newValue)
        }
    }

    var currentUserInformation: UserInformation? {
        get {
            let userInfo: UserInformation? = self.vendorStore.fetch(itemQueryProvider.CurrentUserInformation)
            return userInfo
        }
        set {
            if let currentEnrollmentAccount = self.enrollmentAccount {
                let userIdentifier = newValue?.userIdentifier ?? "-1"
                currentEnrollmentAccount.identifier = Int(userIdentifier) ?? AWEnrollmentAccount.AWDefaultUserIdentifier

                if let username = newValue?.userName {
                    currentEnrollmentAccount.username = username
                }
                if let groupID = newValue?.groupID {
                    currentEnrollmentAccount.activationCode = groupID
                }

                if let email = newValue?.email {
                    self.enrolledUserEmailAddress = email
                }
            }

            _ = self.vendorStore.set(itemQueryProvider.CurrentUserInformation, value: newValue)
        }
    }


}
