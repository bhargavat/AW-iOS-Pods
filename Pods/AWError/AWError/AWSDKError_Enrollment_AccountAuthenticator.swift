//
//  AWSDKError_Enrollment_AccountAuthenticator.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Enrollment {
    enum AccountAuthenticator: AWSDKErrorType {
        case consoleServicesConfigNotSet
        case cannotParseUserID
    }
}

public extension AWError.SDK.Enrollment.AccountAuthenticator {
    var localizableInfo: String? {
        switch self {
        case .consoleServicesConfigNotSet:
            return "Console Services Config is not set properly."
        case .cannotParseUserID:
            return "AWEnrollmentAccountAuthenticator failed to parse user ID from UserRemoteAuthResponse."
        }
    }
}
