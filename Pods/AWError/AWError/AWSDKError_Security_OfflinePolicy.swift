//
//  AWSDKError_Security_OfflinePolicy.swift
//  AWError
//
//  Created by "Liu, Troy" on 8/31/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Security {
    enum OfflinePolicy: AWSDKErrorType {
        case violated
        case useCountPolicyViolated
        case useDurationPolicyViolated
    }
}

public extension AWError.SDK.Security.OfflinePolicy {
    var errorDescription: String {
        switch self {
        case .violated:
            return "The device has broken the device compliance policy for being offline."
        case .useCountPolicyViolated:
            return "The device has broken the device compliance policy for being used offline more than allowed number of times."
        case .useDurationPolicyViolated:
            return "The device has broken the device compliance policy for being used offline more than allowed duration."
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .violated:                  return "OfflineAccessNotAllowed"
        case .useCountPolicyViolated:    return nil
        case .useDurationPolicyViolated: return "OfflineAccessDurationExceeded"
        }
    }
}
