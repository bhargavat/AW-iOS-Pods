//
//  AWSDKError_CryptoKit_Passphrase.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.CryptoKit {
    enum Passphrase: AWSDKErrorType {
        case keyDerivationFailed(OSStatus)
    }
}

public extension AWError.SDK.CryptoKit.Passphrase {
    var code: Int {
        switch self {
        case .keyDerivationFailed(let statusCode):
            return Int(statusCode)
        }
    }
}
