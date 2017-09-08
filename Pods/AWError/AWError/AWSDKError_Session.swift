//
//  AWSDKError_Session.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Session: AWSDKErrorType {
        case failedToGetToken
        case failedToInvalidateToken
    }
}

public extension AWError.SDK.Session {
    var localizableInfo: String? {
        switch self {
        case .failedToGetToken:
            return "FailedToGetToken"
        case .failedToInvalidateToken:
            return "FailedToInvalidateToken"
        }
    }
}
