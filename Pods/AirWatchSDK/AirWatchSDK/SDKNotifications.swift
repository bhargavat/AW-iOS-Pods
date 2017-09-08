//
//  DataChangeNotification.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal protocol PostableNotification {
    var name: String { get }
    func post(data: AnyObject?)
}

internal extension PostableNotification where Self: RawRepresentable {
    func post(data: AnyObject? = nil) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: self.name), object: data)
    }

}

internal enum DataChangeNotification: String, PostableNotification {

    var name: String { return self.rawValue }

    case HMACSaved = "AWHMACSavedNotification"

    case HMACChanged = "AWHMACChangedNotification"
    
    case HMACRefreshed = "AWHMACRefreshNotification"
}

internal enum SecurityUpdateNotification: String, PostableNotification {

    case MasterKeyStoreUpdate = "AWMasterKeySToreUpdateNotification"

    var name: String { return self.rawValue }

}
