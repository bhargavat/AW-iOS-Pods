//
//  Protocols.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#if sdk_mixpanel_data_collection_enabled
import Foundation
import SDKMixpanel
import AWServices

internal protocol SDKDataCollectionService {

    func startDataCollection()

    func stopDataCollection()

    func flushCollectedData()

    func track(user: DataCollectionUser)

    func time(event: DataCollectionUserActionEvent)
    
    func constructUserProperties(profile: Profile, datastore: SDKContext)
    
    func track(event: DataCollectionUserActionEvent)
}

internal extension SDKDataCollectionService {
    
    func constructUserProperties(profile: Profile, datastore: SDKContext) {
        if  let url =  datastore.deviceServices?.config.airWatchServerURL,
            let group =  datastore.deviceServices?.config.organizationGroup,
            let authenticationPayload = profile.authenticationPayload,
            let sdkMixPanel = SDKMixpanelDataCollectionService.sharedInstance {
            
            if let username = datastore.enrollmentAccount?.username,
                let encodedString = username.toData()?.sha256?.base64EncodedString() {
                
                sdkMixPanel.mixpanel?.identify(distinctId: encodedString)
                sdkMixPanel.mixpanel?.people.set(properties: ["$name":encodedString])
            } else {
                log(error: "Could not resolve a distinct ID for Mixpanel. Ending early and stoping mixpanel")
                sdkMixPanel.flushCollectedData()
                sdkMixPanel.stopDataCollection()
                return
            }
            
            let sdkVersion = AWController.sharedInstance.AWSDKVersion
            var profileName = "Unknown"
            // General User Settings
            if let sdkProfileType = profile.displayName, sdkProfileType.characters.count > 0 {
                profileName = sdkProfileType
            }
            
            var proxyType: String = "\(ProxyType.none)"
            if let payload = profile.proxyPayload {
                proxyType = "\(payload.proxyType)"
            }
            
            var dataLossPrevention = false
            if let dlp = profile.restrictionsPayload?.enableDataLossPrevention {
                dataLossPrevention = dlp
            }
            
            // If the user selectes 0 on console, then the profile sets the timeout to Int.max. To avoid showing a really large number on mixpanel we'll report 0
            var timeout: Int = authenticationPayload.passcodeTimeout
            if timeout == Int.max {
                timeout = 0
            }
            
            var biometricMethod = BiometricMethod.none
            if BiometricsHelper.isTouchIDSupported() {
                biometricMethod = authenticationPayload.biometricMethod
            }
            
            var maximumFailedAttempts = 0
            if authenticationPayload.maximumFailedAttempts != 9999 {
                maximumFailedAttempts = authenticationPayload.maximumFailedAttempts
            }
            
            let userProperties = SDKMixpanelProperties(profileType: profileName,
                                                       authenticationType: "\(authenticationPayload.authenticationMethod)",
                sdkVersion: sdkVersion,
                ssoMode: authenticationPayload.enableSingleSignOn,
                biometric: "\(biometricMethod)",
                integratedAuthenticationEnabled: authenticationPayload.enableIntegratedAuthentication,
                authenticationTimeout: timeout,
                proxyType: proxyType,
                dataLossPrevention: dataLossPrevention,
                passcodeHistory: authenticationPayload.maximumPasscodeAge,
                passcodeLength: authenticationPayload.minimumPasscodeLength,
                allowSimplePasscode: authenticationPayload.allowSimple,
                maximumFailedAttempts: maximumFailedAttempts,
                passcodeMode: "\(authenticationPayload.passcodeMode)",
                environment: url,
                group: group)
            
            sdkMixPanel.track(user: userProperties)
        }
    
    }
    
    func track(user: DataCollectionUser) {
        let properties = user.toProperties()
        SDKMixpanelDataCollectionService.sharedInstance?.mixpanel?.people.set(properties: properties)
        SDKMixpanelDataCollectionService.sharedInstance?.mixpanel?.registerSuperProperties(properties)
    }
}

internal protocol DataCollectionUserActionEvent {
    var name: String { get }
    var properties: [String: MixpanelType] { get }
}

internal protocol DataCollectionUser {
    func toProperties() -> [String: MixpanelType]
}

internal struct SDKMixpanelProperties: DataCollectionUser {
    var profileType: String
    var authenticationType: String
    var sdkVersion: String
    var ssoMode: Bool
    var biometric: String
    var integratedAuthenticationEnabled: Bool
    var authenticationTimeout: Int
    var proxyType: String
    var dataLossPrevention: Bool
    var passcodeHistory: Int
    var passcodeLength: Int
    var allowSimplePasscode: Bool
    var maximumFailedAttempts: Int
    var passcodeMode: String
    var environment: String
    var group: String
    
    func toProperties() -> [String : MixpanelType] {
        let properties: [String: MixpanelType] = [
            "Profile Type": profileType,
            "Authentication Type":  authenticationType,
            "SDK Version":          sdkVersion,
            "SSO Mode":             ssoMode,
            "Biometric Method":     biometric,
            "IA":                   integratedAuthenticationEnabled,
            "Authentication Timeout": authenticationTimeout,
            "Proxy Type":           proxyType,
            "DLP":                  dataLossPrevention,
            "Passcode History":     passcodeHistory,
            "Passcode Length":      passcodeLength,
            "Allow Simple Value":   allowSimplePasscode,
            "Maximum failed attempts allowed": maximumFailedAttempts,
            "Passcode Mode":        passcodeMode,
            "Environment":          environment,
            "Group ID":             group
        ]
        return properties
    }
}
#endif
