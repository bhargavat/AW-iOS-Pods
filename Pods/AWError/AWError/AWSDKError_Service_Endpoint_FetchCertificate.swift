//
//  AWSDKError_Service_Endpoint_FetchCertificate.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Service.Endpoint {
    enum FetchCertificate: AWSDKErrorType {
        case noAuthorizerForCertificateFetching
        case unsupportedResponseType(String)
        case invalidCertificateData
    }
}

public extension AWError.SDK.Service.Endpoint.FetchCertificate {
    var localizableInfo: String? {
        switch self {
        case .noAuthorizerForCertificateFetching:
            return "Valid authorizer is required for fetching profile"
        case .unsupportedResponseType(let type):
            return "\(type) is not supported"
        case .invalidCertificateData:
            return "Invalid certificate data"
        }
    }
}
