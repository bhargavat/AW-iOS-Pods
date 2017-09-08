//
//  AWSDKError_Security_General.swift
//  AWError
//
//  Created by "Liu, Troy" on 8/31/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Security {
    enum General: AWSDKErrorType {
        case applicationSecurityDisabled
    }
}

public extension AWError.SDK.Security.General {
    var errorDescription: String {
        switch self {
        case .applicationSecurityDisabled:
            return "The application has the security module disabled."
        }
    }
}
