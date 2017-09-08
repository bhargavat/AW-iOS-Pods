//
//  AWSDKError_CorePlatformHelpers_SwiftStructSerialization.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.CorePlatformHelpers {
    enum SwiftStructSerialization: AWSDKErrorType {
        case structRequired
        case unsupportedSerializationType(label: String?)
    }
}

public extension AWError.SDK.CorePlatformHelpers.SwiftStructSerialization {
    var localizableInfo: String? {
        switch self {
        case .structRequired:
            return "A Swift Struct is required"
        case .unsupportedSerializationType(let label):
            return "Unsupported member type for \(String(describing: label))"
        }
    }
}
