//
//  AWSDKError_Profile_General.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Profile {
    enum General: AWSDKErrorType {
        case invalidDisplayName
        case invalidComments
        case invalidIndentifier
        case invalidOrganization
        case invalidType
        case invalidUUID
        case invalidVersion
        case invalidSettings
        case invalidContent
    }
}
