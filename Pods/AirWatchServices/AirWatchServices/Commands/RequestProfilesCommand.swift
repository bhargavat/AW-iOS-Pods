//
//  RequestProfilesCommand.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal struct RequestProfilesCommandImpl: RequestProfilesCommand {

    let UUID: String
    let type = AWServices.CommandType.requestProfiles
    let commandInfo: [String: AnyObject]
    
    init?( info: [String: AnyObject]) {
        guard let uuid = info["CommandUUID"] as? String else {
            return nil
        }

        self.UUID = uuid
        self.commandInfo = info
    }
}
