//
//  ServerDetails.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

struct ServerDetails {
    var serverURL : String
    var groupID : String
    init(serverURL: String, groupID: String) {
        self.serverURL = serverURL
        self.groupID = groupID
    }
}
