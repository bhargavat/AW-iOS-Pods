//
//  AWSDKError_Hardware.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Hardware: AWSDKErrorType {
        case outOfMemory
    }
}

public extension AWError.SDK.Hardware {
    var errorDescription: String {
        switch self {
        case .outOfMemory: return "Request for a memory block from the list or heap coult not be completed."
        }
    }
}
