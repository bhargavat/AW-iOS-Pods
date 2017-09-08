//
//  SDKErrors.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc
public final class AWSDKErrorDomains: NSObject {
    /**
     @brief Domain for intialCheckDone errors which cause the AWSDK to stop execution.
     
     @description The AWSDK setup flow begins when the application starts for the first time or on everytime the application comes into foregroud. The call to initialCheckDone occurs when it has finished its work with either an error or nil if everything finished successfully. 
     */
    public static let setup = "AWSDKSetupErrorDomains"
    public static let encryptedStore = "AWSDKErrorEncryptedStore"
}

@objc
public enum AWSDKSetupError: Int {
    case InternalError = 0
    case StopSDKRequested
    case RegisteringApplicationBlocked
    case EnrollmentInformationSetup
    case EmptyProfiles
    case ProxyFailedToStart
    case IntegratedAuthenticationCertificatesNotDownloaded
    case ApplicationIdentityNotSet
    case FailedToFetchPinningCertificate
    case FailedToFetchEnvironmentInformationFromAirWatchApplication
    case CallBackSchemeNotConfigured
    case AirWatchApplicationSchemeNotWhitelisted
    case AnchorRequiredForThirdPartyApplictionBootstrap
    case FailedToReportUnenrollmentStatus
    case UserFailedtoUnlockProtectedDataInMaximumAllowedAttempts
    case DeviceIsCompromised
    case ConsoleVersionNotCompatible
}

@objc
public enum AWSDKEncryptedStoreError: Int {
    case storeIsLocked
    case storeTypeNotSupported
    case storeMigrationFailed
    case fileDoesNotExist
    case internalEncryptionError
    case internalError
}
