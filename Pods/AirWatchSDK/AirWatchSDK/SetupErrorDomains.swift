//
//  SDKSetupError.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWLocalization

internal extension AWError.SDK {
    // These errors will be returned to both in house and third part developers as an NSError from initial check done
    enum Setup: AWSDKErrorType {
        case internalError
        case stopSDKRequested
        case registeringApplicationBlocked
        case enrollmentInformationSetup
        case emptyProfiles
        case proxyFailedToStart
        case integratedAuthenticationCertificatesNotDownloaded
        case applicationIdentityNotSet
        case failedToFetchPinningCertificate
        case failedToFetchEnvironmentInformationFromAirWatchApplication
        case callBackSchemeNotConfigured
        case airWatchApplicationSchemeNotWhitelisted
        case anchorRequiredForThirdPartyApplictionBootstrap
        case failedToReportUnenrollmentStatus
        case userFailedtoUnlockProtectedDataInMaximumAllowedAttempts
        case deviceIsCompromised
        case consoleVersionNotCompatible
    }
}

extension AWError.SDK.Setup {
    internal var domain: String {
        return AWSDKErrorDomains.setup
    }
    
    internal var shouldBlockApplicationFromMovingForward: Bool {
        switch self {
        case .internalError                                             : fallthrough
        case .stopSDKRequested                                          : fallthrough
        case .registeringApplicationBlocked                             : fallthrough
        case .enrollmentInformationSetup                                : fallthrough
        case .emptyProfiles                                             : fallthrough
            
        case .integratedAuthenticationCertificatesNotDownloaded         : fallthrough
        case .applicationIdentityNotSet                                 : fallthrough
            
        case .failedToFetchEnvironmentInformationFromAirWatchApplication: fallthrough
        case .callBackSchemeNotConfigured                               : fallthrough
        case .airWatchApplicationSchemeNotWhitelisted                   : fallthrough
        case .anchorRequiredForThirdPartyApplictionBootstrap            : fallthrough
        case .failedToReportUnenrollmentStatus                          : fallthrough
        case .userFailedtoUnlockProtectedDataInMaximumAllowedAttempts   : fallthrough
        case .deviceIsCompromised                                       : return true
            
        default:
            return false
        }
    }
    
    internal var localizedDescription: String {
        switch self {
        case .internalError:
            return "InternalError".localized
            
        case .stopSDKRequested:
            return "SetupStopSDKRequested".localized

        case .registeringApplicationBlocked:
            return "RegisteringApplicationBlocked".localized

        case .enrollmentInformationSetup:
            return "EnrollmentInformationSetup".localized

        case .emptyProfiles:
            return "EmptyProfiles".localized

        case .proxyFailedToStart:
            return "TheProxyConfigurationIsMissing".localized

        case .integratedAuthenticationCertificatesNotDownloaded:
            return "IntegratedAuthenticationCertificatesNotDownloaded".localized

        case .applicationIdentityNotSet:
            return "ApplicationIdentityNotSet".localized

        case .failedToFetchPinningCertificate:
            return "FailedToFetchPinningCertificate".localized

        case .failedToFetchEnvironmentInformationFromAirWatchApplication:
            return "FailedToFetchEnvironmentInformationFromAirWatchApplication".localized

        case .callBackSchemeNotConfigured:
            return "ApplicationConfiguredIncorrectly".localized

        case .airWatchApplicationSchemeNotWhitelisted:
            return "ApplicationConfiguredIncorrectly".localized

        case .anchorRequiredForThirdPartyApplictionBootstrap:
            return "StandAloneWithThirdPartyBlock".localized

        case .userFailedtoUnlockProtectedDataInMaximumAllowedAttempts:
            return "UserFailedtoUnlockProtectedDataInMaximumAllowedAttempts".localized

        case .failedToReportUnenrollmentStatus:
            return "FailedToReportUnenrollmentStatus".localized
            
        case .deviceIsCompromised:
            return "DeviceIsCompromised".localized
            
        case .consoleVersionNotCompatible:
            return "ConsoleVersionNotCompatible".localized
        }
    }
    
    internal var errorDescription: String? {
        switch self {
        case .internalError:
            return "Internal error occured within the SDK."
            
        case .stopSDKRequested:
            return "Call to stop AWSDK from app before initialization could be done."

        case .registeringApplicationBlocked:
            return "When attempting to register application, console has blocked us from registering"

        case .enrollmentInformationSetup:
            return "Enrollment status could not be compeleted."

        case .emptyProfiles:
            return "No profiles have been downloaded, and there were no saved profile(s)."

        case .proxyFailedToStart:
            return "Proxy was not able to start using the profile."

        case .integratedAuthenticationCertificatesNotDownloaded:
            return "Integrated Authenticaiton certificates could not be downloaded."

        case .applicationIdentityNotSet:
            return "Failed to verify application status from server."

        case .failedToFetchPinningCertificate:
            return "Failed to download certificates to do certificate pinning"

        case .failedToFetchEnvironmentInformationFromAirWatchApplication:
            return "Failed to fetch environment information for app."

        case .callBackSchemeNotConfigured:
            return "Callback scheme has not been set on AWController's instance. Please set your app's custom URL scheme"

        case .airWatchApplicationSchemeNotWhitelisted:
            return "No airwatch application URLs schemes have been whitelisted in app's info.plist. Please whitelist airwatch app's custom URL scheme"

        case .anchorRequiredForThirdPartyApplictionBootstrap:
            return "Attempted to run a third party application as standalone when a container app is not installed."

        case .failedToReportUnenrollmentStatus:
            return "Failed to report unenrollment status to the console."

        case .userFailedtoUnlockProtectedDataInMaximumAllowedAttempts:
            return "User Failed to Unlock Protected Data in Maximum Allowed Attempts"
            
        case .deviceIsCompromised:
            return "Device is compromised"
            
        case .consoleVersionNotCompatible:
            return "Console version is not compatible with current version of SDK"
        }
    }
    
}
