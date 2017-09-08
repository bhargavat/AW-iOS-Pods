//
//  AWSDKError_Service_General.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Service {
    enum General: AWSDKErrorType {
        case invalidHTTPURL (String)
        case plistSerialization
        case jsonSerialization
        case invalidJSONResponse
        case unexpectedResponse
    }
}

public extension AWError.SDK.Service.General {
    var localizableInfo: String? {
        switch self {
        case .invalidHTTPURL(let invalidUrl):
            return "Invalid HTTP URL: \(invalidUrl)"
            
        case .jsonSerialization, .plistSerialization:
            return "The service request could not be prepared."
            
        case .invalidJSONResponse:
            return "The service response could not be parsed."
            
        case .unexpectedResponse:
            return "The service response is unexpected, so it could not be used."
        }
    }
}
