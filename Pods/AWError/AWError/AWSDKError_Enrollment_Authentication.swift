//
//  AWSDKError_Enrollment_Authentication.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Enrollment {
    enum Authentication: AWSDKErrorType {
        case invalidActivationCode
        case invalidCredentials
        case deviceNotFound
        case deviceNotEnrolled
        case accountDeviceMismatch
        case hmacTokenDoesNotExist
    }
}

public extension AWError.SDK.Enrollment.Authentication {
    var errorDescription: String {
        switch self {
        case .invalidActivationCode:
            return "The enrollment activation code was invalid."
        case .invalidCredentials:
            return "The enrollment credentials were invalid."
        case .deviceNotFound:
            return "The device could not be found on the specified AirWatch instance."
        case .deviceNotEnrolled:
            return "The device was found on the specified AirWatch instance, but appears to be unenrolled."
        case .accountDeviceMismatch:
            return "The authenticated user has not enrolled using this device."
        case .hmacTokenDoesNotExist:
            return "Cannot fetch certififcate as no Hmac found, returning with error"
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .invalidActivationCode:
            return "InvalidActivationCodeErrorMessage"
        case .invalidCredentials:
            return "InvalidCredentialsTitle"
        case .deviceNotFound:
            return "DeviceNotFoundErrorMessage"
        case .deviceNotEnrolled:
            return "DeviceNotEnrolledErrorMessage"
        case .accountDeviceMismatch:
            return "DeviceMismatchErrorMessage"
        default:
            return nil
        }
    }
}
