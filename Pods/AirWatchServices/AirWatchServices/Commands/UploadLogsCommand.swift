//
//  UploadLogsCommand.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal struct UploadLogsCommandImpl: UploadLogsCommand {
    let UUID: String
    let type = AWServices.CommandType.uploadLogs
    let consoleLogLevel: Int
    let logPeriod: TimeInterval
    let commandInfo: [String: AnyObject]
    
    init?( info: [String: AnyObject]) {
        guard
            let uuid = info["CommandUUID"] as? String,
            let commandInfo = info["Command"],
            let level = commandInfo["LogLevel"] as? Int,
            let period = commandInfo["LogPeriod"] as? Double
        else {
            return nil
        }

        self.UUID = uuid
        self.consoleLogLevel = level
        self.logPeriod = TimeInterval(period)
        self.commandInfo = info
    }
}
