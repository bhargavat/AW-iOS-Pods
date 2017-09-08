//
//  AWSDKError_Registration.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Registration: AWSDKErrorType {
        case masterHMACEmpty
        case applicationIdentifierEmpty
        case usingAnchorFailed
        case didNotComplete
        case tokenIsEmpty
    }
}

public extension AWError.SDK.Registration {
    var code: Int {
        // The code start from 22000 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWSDKErrors_Private.h
        return _code + 22000
    }
    
    var localizableInfo: String? {
        switch self {
        case .masterHMACEmpty:            return "SharedHMACIsEmpty"
        case .applicationIdentifierEmpty: return "RegisteringApplicationIdentifierEmpty"
        case .usingAnchorFailed:          return "LocalRegistrationWithAnchorFailed"
        case .tokenIsEmpty:               return "RegistrationTokenEmpty"
        default:                          return nil
        }
    }
    var errorDescription: String {
        switch self {
        case .masterHMACEmpty:            return "Shared HMAC was empty"
        case .applicationIdentifierEmpty: return "Identifier of registering application is empty"
        case .usingAnchorFailed:          return "Registration with anchor failed"
        case .didNotComplete:             return "Registration did not complete"
        case .tokenIsEmpty:               return "Registration token is empty"
        }
    }
}
