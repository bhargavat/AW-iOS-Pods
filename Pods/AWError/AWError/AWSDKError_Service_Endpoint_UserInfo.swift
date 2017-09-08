//
//  AWSDKError_Service_Endpoint_UserInfo.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Service.Endpoint {
    enum UserInfo: AWSDKErrorType {
        case missingResponseData
        case invalidResponseData
        case receivedStatusCode401
        case receivedStatusCode403
        case receivedStatusCode404
        case serverError
        case otherError(Int)
        case genericError
    }
}

public extension AWError.SDK.Service.Endpoint.UserInfo {
     var code: Int {
        switch self {
        case .receivedStatusCode401:
            return 401
        case .receivedStatusCode403:
            return 403
        case .receivedStatusCode404:
            return 404
        case .otherError(let statusCode):
            return statusCode
        default:
            return _code
        }
    }
}
