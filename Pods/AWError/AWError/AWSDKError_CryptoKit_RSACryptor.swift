//
//  AWSDKError_CryptoKit_RSACryptor.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.CryptoKit {
    enum RSACryptor: AWSDKErrorType {
        case missingPublicKey
        case missingPrivateKey
        
        case decryptionFailed(OSStatus)
        case encryptionFailed(OSStatus)
        
        case signatureVerificationFailed(OSStatus)
        case dataSigningFailed(OSStatus)
    }
}

public extension AWError.SDK.CryptoKit.RSACryptor {
    var code: Int {
        switch self {
        case .decryptionFailed(let statusCode):
            return Int(statusCode)
        case .encryptionFailed(let statusCode):
            return Int(statusCode)
        case .signatureVerificationFailed(let statusCode):
            return Int(statusCode)
        case .dataSigningFailed(let statusCode):
            return Int(statusCode)
            
        default:
            return _code
        }
    }
}
