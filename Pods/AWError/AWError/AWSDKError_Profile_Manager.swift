//
//  AWSDKError_Profile_Manager.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Profile {
    enum Manager: AWSDKErrorType {
        case failedToFetchProfile
        case unknownConfigurationProfileType
    }
}
