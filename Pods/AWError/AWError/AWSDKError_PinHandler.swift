//
//  AWSDKError_PinHandler.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

// Corresponding Location in old SDK: AWSDKErrors_Private.h
public extension AWError.SDK {
    enum PinHandler: AWSDKErrorType {
        case validationFailed
        case validationCancelled
    }
}

public extension AWError.SDK.PinHandler {
    // The code starts from 25000 because the following in SDK 5.9
    // AWPinHandlerPinvalidationError = 11000,
    var code: Int {
        return _code + 25000
    }
    
    var localizableInfo: String? {
        switch self {
        case .validationFailed:
            return "PinValidationError"
        default:
            return nil
        }
    }
    
    var errorDescription: String {
        switch self {
        case .validationFailed:
            return "Error while validating pin"
        default:
            return String(describing: self)
        }
    }
}
