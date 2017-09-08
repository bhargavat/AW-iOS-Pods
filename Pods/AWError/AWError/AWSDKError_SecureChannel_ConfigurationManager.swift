//
//  AWSDKError_SecureChannel_ConfigurationManager.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.SecureChannel {
    enum ConfigurationManager: AWSDKErrorType {
        case serverCertificateValidationFailed(String)
        case serverCertificateCorrupted(String)
    }
}

public extension AWError.SDK.SecureChannel.ConfigurationManager {
    
    var hostname: String {
        switch self {
        case .serverCertificateValidationFailed(let hostname):
            return hostname
        case .serverCertificateCorrupted(let hostname):
            return hostname
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .serverCertificateValidationFailed(let hostname):
            return "Validation failed for the secure channel server certificate for hostname: \(hostname)"
        case .serverCertificateCorrupted(let hostname):
            return "Corrupted or Invalid certificate provided as secure channel server certificatefor hostname: \(hostname)"
        }
    }
    
    var userInfo: AWErrorInfoDict? {
        var userInfoDict: AWErrorInfoDict = _userInfo!
        userInfoDict["hostname"] = hostname
        return userInfoDict
    }
}
