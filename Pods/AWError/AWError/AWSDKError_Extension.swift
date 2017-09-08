//
//  AWSDKpublic extensionError.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

// Corresponding Location in old SDK: AWSDKErrors_Private.h

public extension AWError.SDK {
    enum Extension: AWSDKErrorType {
        case anchorCommunicationError
        case notRegisteredError
    }
}

public extension AWError.SDK.Extension {
    var errorDescription: String {
        switch self {
        case .anchorCommunicationError:
            return "public extension app cannot communicate with Anchor"
        default:
            return String(describing: self)
        }
    }
}
