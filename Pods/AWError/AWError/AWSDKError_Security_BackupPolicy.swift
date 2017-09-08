//
//  AWSDKError_Security_BackupPolicy.swift
//  AWError
//
//  Created by "Liu, Troy" on 8/31/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Security {
    enum BackupPolicy: AWSDKErrorType {
        case violated
    }
}

public extension AWError.SDK.Security.BackupPolicy {
    var errorDescription: String {
        switch self {
        case .violated:
            return "The device has broken the device compliance policy for being installed from a backup"
        }
    }
}
