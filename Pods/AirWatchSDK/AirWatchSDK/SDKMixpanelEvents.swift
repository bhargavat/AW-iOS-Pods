//
//  SDKLifeCycleEvents.swift
//  AWDataCollection
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
internal enum LockType: String {
    case unknown    = "Unknown"
    case manual     = "Manual"
    case timeout    = "Timeout"
    case command    = "Command"
}
internal enum UnlockType: String {
    case passcode   = "Passcode"
    case usernamePassword = "UsernamePassword"
    case touchID    = "TouchID"
}

internal enum SDKSettings {
    case authentication(String)
    case SSOStatus(Bool)
    case passcodeLength(Int)
    case proxyEnabled(Bool)
    case proxyType(String)
    case biometric(String)
    case authenticationTimeoutPeriod(Int)
    case profileType(String)
}

#if sdk_mixpanel_data_collection_enabled
import SDKMixpanel

internal enum SDKLifeCycleEvent{
    case initialization(Bool, String?)
    case activation(Bool)
    case locked(LockType)
    case unlocked(UnlockType)
    static let Start:SDKLifeCycleEvent =  SDKLifeCycleEvent.initialization(true, nil)
}

internal extension SDKLifeCycleEvent: DataCollectionUserActionEvent {
    var name: String {
        switch self {
        case .initialization(_,_):
            return "SDK Started"
        case .activation(_):
            return "SDK Activated"
        case .locked(let lockedType):
            return "SDK Locked: \(lockedType.rawValue)"
        case .unlocked(let unlockedType):
            return "SDK Unlocked: \(unlockedType.rawValue)"
        }
    }

    var properties: [String: MixpanelType] {
        
        var properties = [String: MixpanelType] ()
        switch self {
        case .initialization(let result, let error):
            properties["result"] = result
            if let errorReason = error {
                properties["error"] = errorReason
            }
        case .activation(let completed):
            properties["Completed"] = completed
        case .locked(let didLock):
            properties["DidLock"] = didLock.rawValue
        case .unlocked(let unlock):
            properties["DidUnlock"] = unlock.rawValue
        }
        return properties
    }
}

internal extension SDKSettings: DataCollectionUserActionEvent {
    var name: String {
        switch self {
        case .authentication(_):
            return "AuthenticationMethod"

        case .SSOStatus(_):
            return "SSOStatus"

        case .passcodeLength(_):
            return "PasscodeLength"

        case .proxyEnabled(_):
            return "ProxyEnabled"

        case .proxyType(_):
            return "ProxyType"

        case .biometric(_):
            return "Biometric"

        case .authenticationTimeoutPeriod(_):
            return "AuthenticationTimeoutPeriod"

        case .profileType(_):
            return "Profile"
        }
    }
    
    var properties: [String: MixpanelType] {
        var properties = [String: MixpanelType] ()
        switch self {
        case .authentication(let auth):
            properties["AuthenticationMethod"] = auth

        case .SSOStatus(let isActive):
            properties["SSOStatus"] = isActive

        case .passcodeLength(let value):
            properties["PasscodeLength"] = value

        case .proxyEnabled(let enabled):
            properties["ProxyEnabled"] = enabled

        case .proxyType(let value):
            properties["ProxyType"] = value

        case .biometric(let status):
            properties["Biometric"] = status

        case .authenticationTimeoutPeriod(let value):
            properties["AuthenticationTimeoutPeriod"] = value

        case .profileType(let value):
            properties["Profile"] = value
        }
        
        return properties
    }
}
#endif
