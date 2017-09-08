//
//  AWSDKError_UDID.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum UDID: AWSDKErrorType {
        case lookupEndpointUnavailable
        case lookupEndpointLookUpFailed
        case lookupEndpointUnsupported
        case ios7LookupEndpointUnavailable
        case ios7LookupEndpointLookUpFailed
        case ios7LookupEndpointUnsupported
        case ios7InvalidMacAddress
        
        case ios7NotCompatible
        case noUDIDPresent
        case notInitialized
        case serverNotSet
        case initializationFailed
        case sdkSchemeNotSet
        case openURLSchemeIsMissing
        case missingParameterInURL
        case failedToParse
    }
}

public extension AWError.SDK.UDID {
    var code: Int {
        // The code starts from 9000 because the following in SDK 5.9
        // AWSDKErrorUIDLookupEndpointUnavailable = 9000,
        // AWSDKErrorUIDLookupEndpointLookUpFailed = 9001,
        // AWSDKErrorUIDLookupEndpointUnsupported = 9002,
        // AWSDKErrorIOS7UIDLookupEndpointUnavailable = 9003,
        // AWSDKErrorIOS7UIDLookupEndpointLookUpFailed = 9004,
        // AWSDKErrorIOS7UIDLookupEndpointUnsupported = 9005,
        // AWSDKErrorIOS7InvalidMacAddress = 9006,
        return _code + 9000
    }
    
    var localizableInfo: String? {
        switch self {
        case .ios7NotCompatible:
            return "UDIDiOS7CompatibiltiyError"
        default:
            return nil
        }
    }
}
