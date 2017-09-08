//
//  AWSDKError_Security_CompromisedPolicy.swift
//  AWError
//
//  Created by "Liu, Troy" on 8/31/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Security {
    enum CompromisedPolicy: AWSDKErrorType {
        case violated
    }
}

public extension AWError.SDK.Security.CompromisedPolicy {
    var errorDescription: String {
        switch self {
        case .violated:
            return "The device has broken the device compliance policy for being compromised"
        }
    }
}
