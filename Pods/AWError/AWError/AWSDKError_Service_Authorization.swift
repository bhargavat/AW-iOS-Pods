//
//  AWSDKError_Service_Authorization.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Service {
    enum Authorization: AWSDKErrorType {
        case invalidInputs
        case invalidServerResponse
        case invalidCredentials
        case accountLockedOut
        case inactiveAccount
        case notMDMEnrolled
        case invalidToken
        case deviceNotFound
        case serverConfigurationIssue
        case missingExpectedServerResponseData
        case missingExpectedAuthToken
        case unknownServerIssue
        case unexpectedServerResponseWithURLStatusCode(statusCode: Int)
        case unexpectedGenericError
    }
}

public extension AWError.SDK.Service.Authorization {
    var code: Int {
        switch self {
        case .unexpectedServerResponseWithURLStatusCode(let statusCode):
            return statusCode
        default:
            return _code
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .invalidCredentials:        return "InvalidCredentialsErrorTitle"
        case .accountLockedOut:          return "AccountLockedErrorMessage"
        case .inactiveAccount:           return "InActiveErrorMessage"
        case .notMDMEnrolled:            return "NotMDMEnrolledErrorMessage"
        case .invalidToken:              return "InvalidTokenErrorMessage"
        case .deviceNotFound:            return "DeviceNotFoundErrorMessage"
        case .unexpectedGenericError:    return "UnknownErrorMessage"
        default:                         return nil
        }
    }
}
