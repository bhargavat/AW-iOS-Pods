//
//  SDKApplication.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


class SDKApplication {
    static var currentAppliction: SDKApplication? = nil

    var context: SDKContext
    init(context: SDKContext) {
        self.context = context
    }

    static var isExtension: Bool {
        return Bundle.main.isExtensionBundle
    }

    var isStandAloneApplication: Bool {
        let anchor = AirWatchAnchor(context: context)

        if anchor.canUseSharedData {
            return false
        }

        if anchor.anchorScheme !=  nil {
            return false
        }

        return true
    }
}
