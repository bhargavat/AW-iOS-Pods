//
//  AWSDKError_Service_Endpoint_CommandLoader.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK.Service.Endpoint {
    enum CommandLoader: AWSDKErrorType {
        case invalidPlist (String)
        case invalidServerURL (String)
        case invalidServerPort (String)
        case invalidServerPath (String)
        case invalidUDID (String)
    }
}

public extension AWError.SDK.Service.Endpoint.CommandLoader {
    var localizableInfo: String? {
        switch self {
        case .invalidPlist(let invalidPlist):
            return "Invalid Plist: \(invalidPlist)"
        case .invalidServerURL(let invalidUrl):
            return "Invalid Server Host URL: \(invalidUrl)"
        case .invalidServerPort(let invalidPort):
            return "Invalid Server Port: \(invalidPort)"
        case .invalidServerPath(let invalidPath):
            return "Invalid Server Path: \(invalidPath)"
        case .invalidUDID(let invalidUDID):
            return "Invalid UDID: \(invalidUDID)"
        }
    }
}
