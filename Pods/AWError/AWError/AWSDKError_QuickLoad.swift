//
//  AWQuickLoadSDKError.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

// Corresponding Location in old SDK: AWSDKErrors_Private.h

import Foundation

public extension AWError.SDK {
    enum QuickLoad: AWSDKErrorType {
        case deviceServicesURLNotFound
        case startedError
    }
}

public extension AWError.SDK.QuickLoad {
    var errorDescription: String {
        switch self {
        case .deviceServicesURLNotFound:
            return "Couldn't load device services URL."
        case .startedError:
            return "AWController started. Use public API to get HMAC."
        }
    }
}
