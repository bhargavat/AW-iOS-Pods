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
import AWStorage
import AWLog

public protocol SDKDataStore {
    var applicationIdentity: Identity? { get }
    var deviceServices: DeviceServices? { get }
    var applicationKey: Data? {mutating get }
}

protocol SDKContext: SDKDataStore, EnrollmentInformationProvider, SDKServerDetailsControllerDatasource, AbstractStorageSecurityProvider, AbstractSessionProvider, SDKEmailAccountControllerDataSource
 {
    func setContext(shared: Bool)
    var lastDataStoreSetupMode: Bool { get set }
    var sharedDataAvailable: Bool { mutating get }
    var sharedKeychainSetup: Bool { get set }
    var currentAnchorScheme: String? { get set }

    // Has Application ever launched?
    var applicationPreviouslyLaunched: Bool { mutating get }
    var commonAuthenticationGroup: String? {get set}
    var commonIdentity: Identity? { get set }

    /// Device Services
    var deviceServices: DeviceServices? { get }
    var commonDeviceServices: DeviceServices? { get }

    // Has Application ever registered?
    var appRegistered: Bool { get set }
    var applicationIdentity: Identity? { get set }
    var onboardedUser: String? { mutating get set }
    var enrolledUserEmailAddress: String? { get set }
    var enrolledUser: String? { get }
    var loggedOut: Bool { get set }
    var isApplicationInStandaloneMode: Bool { get set }
    var identity: NSDictionary? { get set  }
    var username: String? { get set }
    var enrollmentAccount: AWEnrollmentAccount? { get set }
    var userIdentifier: Int { get  }
    var currentUserInformation: UserInformation? { get set }

    var enrollmentInformation: EnrollmentInformation? { get set }
    
    var shouldReportUnenrollment: Bool { get set }

    var sharedApplicationAnalyticsIdentifier: String { get }
    var lastAppliedSDKProfileIdentifier: String? { get  set }
    var appliedAuthenticationPayloadIdentifier: String? { get  set }
    var appliedAuthenticationPayload: AuthenticationPayload? { get set }
    var appliedAuthenticationPayloadTimestamp: TimeInterval? { get }

    var certificatePayload: DataRepresentable? { get set }
    var SSLTrustPublicKeys: [String: [String]]? { get set }
    var timeOfLastSSLTrustKeyFetch: Date? { get set }

    var currentLogLevel: AWLogLevel { get set }
    var commandLogLevel: AWLogLevel { get set }
    var uploadLogTimeStamp: Date? { get set }
    var shouldSendLogsOnlyOnWifi: Bool { get set }

    var enabledSingleSignOn: Bool { get set }
    var isNonSharedToSharedMigrationInProgress: Bool { get set }
    var currentAuthenticationMethod: AWSDK.AuthenticationMethod { mutating get set }
    var isPasscodeSet: Bool { get set }
    var newSDKPasscodeSetDate: Date? { get set} ///This can be removed once we are sure all customers are using at least version 6.0
    var currentPasscodeSetDate: Date? { get set }
    var passcodeHistory: [[Data:Data]]? { get set }
    var failedPasscodeUnlockAttempts: Int { get set }

    var isTouchIDConfigured: Bool { get set }
    var currentBiometricMethod: AWSDK.BiometricMethod { get set }

    var needToEscrowPasscode: Bool { get set }
    var applicationKey: Data? { mutating get set }
    var sharedContainerKey: Data? { mutating get set }

    var lastVerifiedOneTimeToken: String? { get set }
    var latestAPNSToken: String? { get set }

    var consoleVersion: ConsoleVersion? { get set }

    var profiles: [Profile] { get }
    func loadProfile(_ profileType: String) -> Profile?
    mutating func saveProfile(_ profile: Profile) -> Bool
    mutating func wipeAllProfiles() -> Bool
    func resetPreviousUserApplicationSettings() -> Bool

    static func wipeAirWatchData()
    mutating func wipeApplicationData()
    mutating func wipeThirdPartyApplicationData()
}
