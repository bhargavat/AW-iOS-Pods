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


extension SDKContext {

    var profileRequiredSingleSignOn: Bool {
        mutating get {
            if let enabled =  self.SDKProfile?.authenticationPayload?.enableSingleSignOn {
                return enabled
            }

            return false
        }
    }

    var profileRequiredAuthenticationMode: AWSDK.AuthenticationMethod {
        mutating get {
            guard let payload = self.SDKProfile?.authenticationPayload else {
                return .none
            }
            return payload.authenticationMethod
        }
    }

    var profileRequiredPasscode: Bool {
        mutating get {
            guard let payload =  self.SDKProfile?.authenticationPayload else {
                return false
            }
            return payload.passcodeMode != .off
        }
    }

    var profileRequiredBiometricMethod: AWSDK.BiometricMethod {
        mutating get {
            if let bioMetricMethod =  self.SDKProfile?.authenticationPayload?.biometricMethod {
                return bioMetricMethod
            }
            return AWSDK.BiometricMethod.none
        }
    }

    var profileRequiredPasscodeMode: AWSDK.PasscodeMode {
        mutating get {
            if let passcodeMode =  self.SDKProfile?.authenticationPayload?.passcodeMode {
                return passcodeMode
            }
            return AWSDK.PasscodeMode.off
        }
    }

    var SDKProfile: Profile? {
        get {
            let allProfiles = self.profiles
            let sdkprofiles = allProfiles.filter { $0.profileType == AWSDK.ConfigurationProfileType.sdk }
            return sdkprofiles.first
        }
    }

    @available(*, deprecated: 6.0)
    var appProfile: Profile? {
        mutating get {
            let allProfiles = self.profiles
            let appProfiles = allProfiles.filter { $0.profileType != AWSDK.ConfigurationProfileType.sdk }
            return appProfiles.first
        }
    }

}
