//
//  AWSDKError_Beacon.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Beacon: AWSDKErrorType {
        case moduleBusy
        case configFieldsMissing
        case shutdownFailure
        case startUpFailure
        case jsonParsingFailure
        case messageNotInitialized
        case messageSendFailure
        case sendMgrNotInitialized
        case deviceNotEnrolled
        case unknownStatus
    }
}

public extension AWError.SDK.Beacon {
    var errorDescription: String {
        switch self {
        case .moduleBusy:            return "The request could not be processed because other processes are underway."
        case .configFieldsMissing:   return "One or more required fields are missing."
        case .shutdownFailure:       return "Beacon shut down failed - see underlying reason."
        case .startUpFailure:        return "The Beacon module start up failed."
        case .jsonParsingFailure:    return "The response interpreter encountered an error during JSON parsing."
        case .messageNotInitialized: return "Beacon message must be initialized before sending."
        case .messageSendFailure:    return "Beacon message could not be sent - connection failed."
        case .sendMgrNotInitialized: return "Beacon send manager must be initialized before use."
        case .deviceNotEnrolled:     return "Beacon responded from the console with a device not enrolled status."
        case .unknownStatus:         return "Beacon responded from the console with an unknown status code."
        }
    }
}
