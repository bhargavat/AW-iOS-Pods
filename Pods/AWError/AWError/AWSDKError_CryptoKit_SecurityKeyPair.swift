//
//  AWSDKError_CryptoKit_SecurityKeyPair.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.CryptoKit {
    enum SecurityKeyPair: AWSDKErrorType {
        case generationFailed(OSStatus)
        case unavailableForGivenIdentifier
    }
}

public extension AWError.SDK.CryptoKit.SecurityKeyPair {
    var code: Int {
        switch self {
        case .generationFailed(let statusCode):
            return Int(statusCode)
        case .unavailableForGivenIdentifier:
            return _code
        }
    }
}
