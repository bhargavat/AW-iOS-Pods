//
//  CommonDataStore.swift
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

protocol DataStoreItemQueryProvider {
    var itemQueryProvider: KeyValueStoreItemQueryProvider { get }
}

protocol AbstractDataStoreItemLoader: DataStoreItemQueryProvider, SDKContext {
    var keyStore: AbstractKeyValueStore { get set }

    var commonDataStore: AbstractKeyValueStore { get set }
    var SSOStore: AbstractKeyValueStore { get set }
    var vendorStore: AbstractKeyValueStore { get set }
    var masterDataStore: AbstractKeyValueStore { get set }
    var localSettingsStore: LocalSettingsDataStore { get set }
    var profilesStore: LocalSettingsDataStore { get set }
    var pinnedPublicKeysStore: LocalSettingsDataStore { get set }

    var enabledSingleSignOn: Bool { get set }
    var isNonSharedToSharedMigrationInProgress: Bool { get set }
    var sharedDataAvailable: Bool { mutating get }

    var applicationPreviouslyLaunched: Bool { mutating get }

    var commonIdentity: Identity? { mutating get set }

    var appRegistered: Bool { get set }
    var onboardedUser: String? { mutating get set }
    var enrolledUserEmailAddress: String? { get set }
    var enrolledUser: String? { get }
    var applicationIdentity: Identity? { mutating get set }

    var loggedOut: Bool { get set }
    var isApplicationInStandaloneMode: Bool { get set }
    var identity: NSDictionary? { get set  }
    var username: String? { get set }
    var enrollmentAccount: AWEnrollmentAccount? { get set }
    var userIdentifier: Int { get }

    var enrollmentInformation: EnrollmentInformation? { get set }

    var sharedApplicationAnalyticsIdentifier: String { get }
    var lastAppliedSDKProfileIdentifier: String? { get  set }
    var appliedAuthenticationPayload: AuthenticationPayload? { get set }
    var appliedAuthenticationPayloadIdentifier: String? { get set }

    var certificatePayload: DataRepresentable? { get set }
    var SSLTrustPublicKeys: [String : [String]]? { get set }
    var timeOfLastSSLTrustKeyFetch: Date? { get set }

    var currentLogLevel: AWLogLevel { get set }
    var uploadLogTimeStamp: Date? { get set }
    var shouldSendLogsOnlyOnWifi: Bool { get set }


    var sharedKeychainSetup: Bool { get set }
    var currentAnchorScheme: String? { get set }

    var isPasscodeSet: Bool { get set }
    var newSDKPasscodeSetDate: Date? { get set }
    var currentPasscodeSetDate: Date? { get set }
    var passcodeHistory: [[Data:Data]]? { get set }
    var failedPasscodeUnlockAttempts: Int { get set }
    var currentAuthenticationMethod: AWSDK.AuthenticationMethod { mutating get set }
    var currentBiometricMethod: AWSDK.BiometricMethod { get set }
    var isTouchIDConfigured: Bool { get set }
    var payloadIdentifier: String? { get set }
    var applicationKey: Data? { mutating get set }

    var lastVerifiedOneTimeToken: String? { get set }
    var latestAPNSToken: String? { get set }
}
