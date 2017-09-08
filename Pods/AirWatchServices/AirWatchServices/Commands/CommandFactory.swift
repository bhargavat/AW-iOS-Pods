//
//  CommandFactory.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal protocol CommandFactory {
    func createCommand(info: [String: AnyObject]) -> Command?
}

extension CommandFactory {

    func createCommand(info: [String: AnyObject]) -> Command? {
        guard let commandInfo = info["Command"] as? [String: AnyObject] else {
            return nil
        }

        guard let type = commandInfo["RequestType"] as? String else {
            return CustomCommandImpl(info: info)
        }

        switch type {
        case "InstallProfile":
            return InstallProfileCommandImpl(info: info)

        case "DeviceLockSso":
            return LockSSOCommandImpl(info: info)

        case "RequestProfiles":
            return RequestProfilesCommandImpl(info: info)

        case "UploadLogs":
            return UploadLogsCommandImpl(info: info)

        default:
            return CustomCommandImpl(info: info)
        }
    }
}
