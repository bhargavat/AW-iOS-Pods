//
//  AWSDKError_Server.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Server: AWSDKErrorType {
        case pageNotFound
        case unavailable
        case unexpectedServerResponse
        case responseBodyMissing
        case serverResponseError
    }
}

public extension AWError.SDK.Server {
    var code: Int {
        switch self {
        case .pageNotFound:
            return 404
        case .unavailable:
            return 503
        default:
            return _code
        }
    }
    var errorDescription: String {
        switch self {
        case .pageNotFound:             return "http response code 404"
        case .unavailable:              return "http response code 503"
        case .unexpectedServerResponse: return "i.e. not a 200"
        case .responseBodyMissing:      return "error in response body"
        default:                        return String(describing: self)
        }
    }
}
