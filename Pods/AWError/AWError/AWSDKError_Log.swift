//
//  AWSDKLogError.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Log: AWSDKErrorType {
        case noLogsToSend
        case triedToSendEmptyLogFile
        case needsWiFiToSendLogs
    }
}

public extension AWError.SDK.Log {
    var localizableInfo: String? {
        switch self {
        case .noLogsToSend:
            return "NoDeviceLogsToSend"
        case .triedToSendEmptyLogFile:
            return "EmptyLogFile"
        case .needsWiFiToSendLogs:
            return "NeedsWiFiToSendLogData"
        }
    }
}
