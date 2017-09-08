//
//  AWDeviceServiceError.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum DeviceStatus: AWSDKErrorType {
        case deviceServicesURLNil
        case authInvalidCredentials
        case accountLocked
        case inActive
        case notMDMEnrolled
        case invalidToken
        case deviceNotFound
        case syncClientNotEnabled
        case personalContentNotEnabled
        case chatNotEnabled
    }
}

public extension AWError.SDK.DeviceStatus {
    var code: Int {
        return _code - 1000
    }
    
    var localizableInfo: String? {
        switch self {
        case .authInvalidCredentials:    return "InvalidCredentialsErrorTitle"
        case .accountLocked:             return "AccountLockedErrorMessage"
        case .inActive:                  return "InActiveErrorMessage"
        case .notMDMEnrolled:            return "NotMDMEnrolledErrorMessage"
        case .invalidToken:              return "InvalidTokenErrorMessage"
        case .deviceNotFound:            return "DeviceNotFoundErrorMessage"
        case .syncClientNotEnabled:      return "SyncClientNotEnabledErrorMessage"
        case .personalContentNotEnabled: return "PersonalContentNotEnabledErrorMessage"
        case .chatNotEnabled:            return "AwchatNotEnabled"
        default:                         return nil
        }
    }
}
