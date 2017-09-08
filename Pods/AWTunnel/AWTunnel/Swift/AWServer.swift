//
//  AWServer.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
    This class is a bridge between the local keychain store  (Swift) and proxy/tunnel classes (ObjC). It
    also provides backward compatibility so that changes to existing code would be minimized. It shouldn't
    be used outside of this module.
 */
@objc
open class AWServer: NSObject {
    open static let sharedInstance = AWServer()

    open var deviceServicesURL: URL? {
        if let url =  AWTunnelService.sharedInstance.deviceServicesURL {
            return url as URL
        } else {
            /// Read from keychain?
            if let resultValue: String = Settings.store.get(SecureItemType.awServerURL, valueType: SettingType.string).value() {
                return URL(string: resultValue)
            } else {
                return nil
            }
        }
    }
}
