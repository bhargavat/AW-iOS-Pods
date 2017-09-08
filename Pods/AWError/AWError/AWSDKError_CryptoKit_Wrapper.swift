//
//  AWSDKError_CryptoKit_Wrapper.swift
//  AWError
//
//  Created by "Liu, Troy" on 9/7/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.CryptoKit {
    enum Wrapper: AWSDKErrorType {
        case encryptionFailed(OSStatus)
        case decryptionFailed(OSStatus)
        
        case keyGenerationFailed(OSStatus)
        case pubKeyConversionFailed(OSStatus)
        case signatureVerificationFailed(OSStatus)
        case dataSigningFailed(OSStatus)
    }
}

public extension AWError.SDK.CryptoKit.Wrapper {
    var code: Int {
        switch self {
        case .encryptionFailed(let statusCode):
            return Int(statusCode)
        case .decryptionFailed(let statusCode):
            return Int(statusCode)
        case .keyGenerationFailed(let statusCode):
            return Int(statusCode)
        case .pubKeyConversionFailed(let statusCode):
            return Int(statusCode)
        case .signatureVerificationFailed(let statusCode):
            return Int(statusCode)
        case .dataSigningFailed(let statusCode):
            return Int(statusCode)
        }
    }
}
