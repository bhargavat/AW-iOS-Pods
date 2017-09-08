//
//  AWSDKError_MDMInformation.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum MDMInformation: AWSDKErrorType {
        case failedParse
        case serverURLNotSet
        case endpointUnavailable
        case endPointAuthenticationFailed
        case unexpectedJSONFormat
    }
}

public extension AWError.SDK.MDMInformation {
    var errorDescription: String {
        switch self {
        case .failedParse:
            return "Console responded with 200 status code, but failed parsing the response data"
        case .endpointUnavailable:
            return "The console responded with a 404 error."
        case .endPointAuthenticationFailed:
            return "The console responded with a 403 error."
        case .unexpectedJSONFormat:
            return "Enrollment Status Response: Console responded with 200 status code but with unexpected JSON format."
        default:
            return String(describing: self)
        }
    }
}
