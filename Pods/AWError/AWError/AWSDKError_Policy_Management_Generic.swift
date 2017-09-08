//
//  AWSDKError_Policy_Management_Generic.swift
//  AWError
//
//  Created by "Liu, Troy" on 8/31/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Policy.Management {
    enum Generic: AWSDKErrorType {
        case utError
        case enforcerCancelledEarly
        case missingNetworkConnection
        case missingDeviceServices
        case missingRequiredAuthenticator
        case unknown
    }
}

public extension AWError.SDK.Policy.Management.Generic {
    var code: Int {
        switch self {
        case .utError:
            return -1
        default:
            return _code
        }
    }
}
