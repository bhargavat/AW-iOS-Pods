//
//  AWSDKError_AssetManagement.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum AssetManagement: AWSDKErrorType {
        case deviceNotEnrolled
        case invalidCredentials
        case connectionLost
        case deviceNonCompliant
        case invalidLocationGroup
        case deviceAlreadyCheckedIn
        case deviceAlreadyCheckedOut
        case invalidCheckOutRequest
        case unknownServerError
        case deviceCanNotBeShared
        case failedToGetToken
    }

}

public extension AWError.SDK.AssetManagement {
    var localizableTitle: String? {
        switch self {
        case .invalidCredentials:
            return "InvalidCredentialsTitle"
        case .connectionLost:
            return "ConnectionLostError"
        default:
            return "ErrorTitle"
        }
        
    }
    
    var localizableMessage: String? {
        switch self {
        case .deviceNotEnrolled:
            return "DeviceNotEnrolled"
        case .invalidCredentials:
            return "DeviceCheckoutFailed"
        case .connectionLost:
            return "NetworkConnectionLost"
        case .deviceNonCompliant:
            return "DeviceNonCompliant"
        case .invalidLocationGroup:
            return "InvalidLocationGroup"
        case .deviceAlreadyCheckedIn:
            return "DeviceAlreadyCheckedIn"
        case .deviceAlreadyCheckedOut:
            return "DeviceAlreadyCheckedOut"
        case .invalidCheckOutRequest:
            return "InvalidCheckOutRequest"
        case .unknownServerError:
            return "UnknownServerErrorMessage"
        case .deviceCanNotBeShared:
            return "DeviceCanNotBeShared"
        case .failedToGetToken:
            return "DeviceCheckoutFailed"
        }
    }
    
    var userInfo: AWErrorInfoDict? {
        var userInfoDict: AWErrorInfoDict = _userInfo ?? [:]
        userInfoDict["LocalizedTitle"] = localizableTitle
        userInfoDict["LocalizedMessage"] = localizableMessage
        return userInfoDict
    }
}
