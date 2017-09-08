//
//  AWSDKError_Interrogator.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Interrogator: AWSDKErrorType {
        case moduleIsBusy
        case fieldsMissing
        case shutdownFailure
        case startUpFailure
        case messageNotInitialized
        case messageSendFailure
        case transmitterNotInitialized
    }
}

public extension AWError.SDK.Interrogator {
    var errorDescription: String {
        switch self {
        case .moduleIsBusy:              return "The request could not be processed because other processes are underway."
        case .fieldsMissing:             return "One or more required fields are missing."
        case .shutdownFailure:           return "Interrogator shut down failed - see underlying reason."
        case .startUpFailure:            return "Interrogator start up failed."
        case .messageNotInitialized:     return "Interrogator message must be initialized before sending."
        case .messageSendFailure:        return "Interrogator message could not be sent - connection failed."
        case .transmitterNotInitialized: return "Interrogator send manager must be initialized before use."
        }
    }
}
