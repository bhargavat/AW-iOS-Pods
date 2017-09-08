//
//  SecureData.swift
//  AWSecureSharedStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


struct KeyValueStoreItemQuery: AbstractKeyValueStoreItemQuery {
    var group: String
    var key: String
}


public enum KeyValueStoreItemQueryProvider {
    case nonSharedItem, sharedItem
    static func ofType(_ shared: Bool) -> KeyValueStoreItemQueryProvider {
        return shared ? .sharedItem : .nonSharedItem
    }
}

extension KeyValueStoreItemQueryProvider {
    var appSpecificItem: Bool {
        return self == .nonSharedItem
    }

    func createQuery(group: KeyValueStoreItemStoreType, key: KeyValueStoreItemKeyType) -> KeyValueStoreItemQuery {
        let groupName = self.appSpecificItem ? (Bundle.main.bundleIdentifier ?? KeyValueStoreItemStoreType.NonShared.rawValue) : group.rawValue
        return KeyValueStoreItemQuery(group: groupName, key: key.rawValue)
    }
}

/// Version Information Provider
extension KeyValueStoreItemQueryProvider {

    var StorageVersion: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .CurrentStorageVersion)
    }

    var CurrentConsoleVersion: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .CurrentConsoleVersion)
    }

    var TouchIDConfigured: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .TouchIDConfigured)
    }
}

/// Enrollment Information Provider
extension KeyValueStoreItemQueryProvider {

    var ApplicationServerURL: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .ServiceURL, key: .ApplicationServiceURL)
    }

    var EnrolledUserEmailAddress: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .SharedEnrollmentInfo, key: .EnrolledUserEmailAddress)
    }
    
    var OnboardedUser: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group: .NonShared, key: .OnboardedUser)
    }

    var LocationGroup: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .GroupID, key: .LocationGroup)
    }

    var EnrollmentDeviceUDID: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .SharedEnrollmentInfo, key: .AgentEnrolledDeviceUDID)
    }
    var ContainerEnrollmentDeviceUDID: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .SharedEnrollmentInfo, key: .ContainerModeEnrolledUDID)
    }

    var EnrollmentVerificationDate: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .SharedEnrollmentInfo, key: .EnrollmentStatusCheckDate)
    }

    var EnrollmentStatus: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .SharedEnrollmentInfo, key: .EnrollmentStatus)
    }
    
    var ReportUnenrollment: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .SharedEnrollmentInfo, key: .ReportUnenrollment)
    }
    
    var CommonAuthenticationGroup: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonAuthenticationGroup, key: .CommonAuthenticationGroupKey)
    }

}

//Agent Information
extension KeyValueStoreItemQueryProvider {
    var AnchorScheme: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonDetails, key: .AnchorScheme)
    }

    var SharedKeychainAvailable: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonDetails, key: .SharedKeychainAvailable)
    }

    var CertificateSharingEnabled: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonDetails, key: .CertificateSharingEnabled)
    }
}

extension KeyValueStoreItemQueryProvider {

    var SingleSignOnEnabled: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group: .NonShared, key: .SingleSignOnEnabled)
    }
    var ProtectedWithPasscode: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .ProtectedWithPasscode)
    }
    var AuthenticationType: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .AuthenticationType)
    }
    var LegacyAuthenticationType: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .LegacyAuthenticationType)
    }
    var BiometricMethod: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .BiometricMethod)
    }
    var NewSDKPasscodeSetDate: KeyValueStoreItemQuery {///This can be removed once we are sure all customers are using at least version 6.0
        return createQuery(group: .CommonDetails, key: .NewSDKPasscodeSetDate)
    }
    var CurrentPasscodeSetDate: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .CurrentPasscodeSetDate)
    }
    var PasscodeHistory: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .PasscodeHistory)
    }
    var PasscodeEncrowedSuccessfully: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .CurrentCryptKeyEscrowSuccessful)
    }
    var LastUnlockedTimeStamp: KeyValueStoreItemQuery {
        return createQuery(group: .GlobalLockStatus, key: .LastUnlockedTimeStamp)
    }

    var PasscodeFailedAttemps: KeyValueStoreItemQuery {
        return createQuery(group: .AuthenticationPayload, key: .FailedPasscodeAttempts)
    }

    var EncryptedPasscodeHash: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .EncryptedPinHash)
    }

    var EncryptedPasscode: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .EncryptedPin)
    }

    var IAuthClientCertStoreQuery: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .IAuthClientCert)
    }

}

extension KeyValueStoreItemQueryProvider {

    var EnrollmentAccount: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .EnrollmentAccount)
    }

    var Username: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .RememberUsername)
    }

    var CurrentUserInformation: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .CurrentUserInformation)
    }


    var DefaultPasscode: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .DefaultPin)
    }

}

extension KeyValueStoreItemQueryProvider {

    var AuthenticationPayload: KeyValueStoreItemQuery {
        return createQuery(group: .AuthenticationPayload, key: .AuthenticationPayload)
    }

    var AuthenticationPayloadIdentifier: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .AuthenticationPayloadIdentifier)
    }

}

extension KeyValueStoreItemQueryProvider {

    var LegacyCommonIdentityAuthenticationInformation: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .LegacyCommonIdentity, key: .LegacyCommonIdentityAuthenticationInformation)
    }

    var CommonIdentityAuthenticationInformation: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonIdentity, key: .CommonIdentityAuthenticationInformation)
    }
}

extension KeyValueStoreItemQueryProvider {
    var NonSharedAppIdentityAuthorizationInformation: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group:.NonShared, key: .ApplicationIdentityAuthenticationInformation)
    }

    var ApplicationSecureChannelConfigurationObfuscationKey: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group:.NonShared, key: .SecureChannelConfigurationObfuscationKey)
    }
}

extension KeyValueStoreItemQueryProvider {

    var CryptKeySalt: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .CryptKeySalt)
    }

}

extension KeyValueStoreItemQueryProvider {
    var MasterKeyEncryptedWithCryptKey: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .MasterKeyEncryptedWithCryptKey)
    }
    
    var MasterKeyEncryptedWithTouchIDKey: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .MasterKeyEncryptedWithTouchIDKey)
    }
    var MasterKeyVerificationEncryptedWithTouchIDKey: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .MasterKeyVerificationEncryptedWithTouchIDKey)
    }
    
    var MasterKeyEncryptedWithSessionKey: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .MasterKeyEncryptedWithSessionKey)
    }
    
    var MasterKeyVerificationEncryptedWithSessionKey: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .MasterKeyVerificationEncryptedWithSessionKey)
    }
    
    var CentennialEncryptedWithMasterKey: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .CentennialEncryptedWithMasterKey)
    }
    
    var CentennialVerificationEncryptedWithMasterKey: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .CentennialVerificationEncryptedWithMasterKey)
    }
    
    var CryptKeyToEscrow: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .CryptKeyToEscrow)
    }
    
    var AppKey: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group: .NonShared, key: .ApplicationKey)
    }

    var SharedContainerKey: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonDetails, key: .SharedContainerKey)
    }

}

extension KeyValueStoreItemQueryProvider {

    var SessionInfo: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .SSOSessionInfo)
    }

}

extension KeyValueStoreItemQueryProvider {
    var DefaultPasscodeSalt: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .CryptKeySalt)
    }

//    var SSOPin: KeyValueStoreItemQuery {
//        return createQuery(group: .CommonDetails, itemKey: "com.sso.pin.service.v1")
//    }
//    var CryptData: KeyValueStoreItemQuery {
//        return createQuery(group: .CommonDetails, itemKey: "com.secure.crypt.data.service")
//    }
//
//    var PinStoreV1: KeyValueStoreItemQuery {
//        return createQuery(group: .SSODetails, itemKey: "com.masterkey.pin.store.service.v1")
//    }
//
//    var PinValidateV1: KeyValueStoreItemQuery {
//        return createQuery(group: .SSODetails, itemKey: "com.masterkey.store.pin.validate.service.v1")
//    }
}


extension KeyValueStoreItemQueryProvider {
    var SecureEnclaveQuery: KeyValueStoreItemQuery {
        return createQuery(group: .CommonDetails, key: .TouchIDKeyStoredInSecureEnclave)
    }
}

extension KeyValueStoreItemQueryProvider {
    var SessionTable: KeyValueStoreItemQuery {
        return createQuery(group: .SSODetails, key: .SessionTable)
    }
    
    var RSAKeyPairEncryptedWithMasterKey: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group: .NonShared, key: .RSAKeyPairEncryptedWithMasterKey)
    }
    
    var ApplictionKeyForGlobalSessionTable: KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group: .NonShared, key: .SessionTableEntryKeyPreFix)
    }
    
    var IdentifierForRSAKeyGen:KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.nonSharedItem.createQuery(group: .NonShared, key: .RSAKeyGenerationIdentifierPostFix)
    }
    
}

