//
//  SDKSecurityEvents.swift
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

internal enum SDKSecurityEvent {
    
    case passcodeSet
    
    case passcodeRemoved
    
    case passcodeChanged
    
    case forgotPasscode

    case invalidPasscode
    
    case invalidPasscodeTimeout
    
    case maximumAllowedPasscodeAttemptsReached
    
    case wipedApplicationData
    
}
    
internal extension SDKSecurityEvent: DataCollectionUserActionEvent {
    
    var name: String {
        
        switch self {
            
        case .passcodeSet:
            return "SDK Security Passcode Set By User"
        
        case .passcodeRemoved:
            return "SDK Security Passcode Removed due to Policy Change"
            
        case .passcodeChanged:
            return "SDK Security Passcode Changed by the User"
            
        case .forgotPasscode:
            return "SDK Security User Forgot Passcode"
            
        case .invalidPasscode:
            return "SDK Security User Entered Invalid Passcode"
            
        case .invalidPasscodeTimeout:
            return "SDK Security User Timedout Due to Invalid Passcodes"
            
        case .maximumAllowedPasscodeAttemptsReached:
            return "SDK Security User Entered Maximum Allowed Passcode Attempts"
            
        case .wipedApplicationData:
            return "SDK Security Wiped Application Data"
        }
    }
    
    var properties: [String: MixpanelType] {
        return [:]
    }
    
}
#endif
