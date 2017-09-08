//
//  AWSDKError_AuthenticationHandler
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum AuthenticationHandler: AWSDKErrorType {
        case moduleIsExecuting
        case noDefaultCredentials
        case authenticationFailed
        case pinValidationFailed
        case authenticationCanceled
        case environmentChanged
    }
}

public extension AWError.SDK.AuthenticationHandler {
    var code: Int {
        // The code start from 24000 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWSDKErrors_Private.h
        return _code + 24000
    }
    
    var localizableInfo: String? {
        switch self {
        case .moduleIsExecuting:      return "AuthenticationHandlerExecuting"
        case .noDefaultCredentials:   return "NoTokenFromManagedSetting"
        case .authenticationFailed:   return "TokenAuthenticationFailed"
        case .authenticationCanceled: return "AuthenticationCancelled"
        default:                      return nil
        }
    }
    var errorDescription: String {
        switch self {
        case .moduleIsExecuting:      return "Authentication handler is executing"
        case .noDefaultCredentials:   return "Authentication error: No token found to register"
        case .authenticationFailed:   return "Failed to authenticate using token"
        case .authenticationCanceled: return "Authentication was canceled"
        default:                      return String(describing: self)
        }
    }
}
