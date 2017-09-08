//
//  AWSDKError_CoreNetwork_CTL.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.CoreNetwork {
    enum CTL: AWSDKErrorType {
        case invalidURL
        case invalidAuthorizer
        case startFetchingFailure
        case createRequestFailure(String)
        case requestAuthorizationNotStarted
        case httpStatus(Int, String)
    }
}

public extension AWError.SDK.CoreNetwork.CTL {
    var code: Int {
        switch self {
        case .httpStatus(let (statusCode, _)):
            return statusCode
        default:
            return _code
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .invalidURL:
            return "Invalid Service URL"
        case .invalidAuthorizer:
            return "Either no authorizer or a valid authorizer is needed"
        case .startFetchingFailure:
            return "The fetching can not be started"
        case .createRequestFailure(let url):
            return "Failed to create request for \(url)"
        case .requestAuthorizationNotStarted:
            return "Request authorization cannot be started"
        case .httpStatus(let (statusCode, description)):
            return "Server encountered some error - \(statusCode): \(description)"
        }
    }
}
