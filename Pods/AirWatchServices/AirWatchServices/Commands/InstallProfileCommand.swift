//
//  InstallProfileCommand.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


internal struct InstallProfileCommandImpl: InstallProfileCommand {
    let UUID: String
    let type = AWServices.CommandType.installProfiles
    let commandInfo: [String : AnyObject]
    let profileInfo: Data

    init?(info: [String: AnyObject]) {
        guard
            let uuid = info["CommandUUID"] as? String,
            let commandInfo = info["Command"],
            let payloadData = commandInfo["Payload"] as? Data
            else {
                return nil
        }
        self.UUID = uuid
        self.commandInfo = info
        self.profileInfo = payloadData
    }
}
