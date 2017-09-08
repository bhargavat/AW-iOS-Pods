//
//  UnknownCommand.swift
//  Pods
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


internal struct CustomCommandImpl: CustomCommand {
    let UUID: String
    let commandInfo: [String: AnyObject]
    let type = AWServices.CommandType.custom

    init?( info: [String: AnyObject]) {
        guard let uuid = info["CommandUUID"] as? String else {
                return nil
        }

        self.UUID = uuid
        self.commandInfo = info
    }
}
