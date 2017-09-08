//
//  AWSDKError_Service_Endpoint_ProfileManager.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Service.Endpoint {
    enum ProfileManager: AWSDKErrorType {
        case unknownConfigurationProfile
        case noAuthorizerForProfileFetching
    }
}

public extension AWError.SDK.Service.Endpoint.ProfileManager {
    var localizableInfo: String? {
        switch self {
        case .unknownConfigurationProfile:
            return "Unknown configuration profile"
        case .noAuthorizerForProfileFetching:
            return "Valid authorizer is required for fetching profile"
        }
    }
}
