//
//  ManagedSettingsStore.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

open class SDKManagedSettings {

    open static let currentSetings = SDKManagedSettings()

    open var managedConfig: [String: AnyObject]? {
        let userDefaults = UserDefaults.standard
        return userDefaults.dictionary(forKey: "com.apple.configuration.managed") as [String : AnyObject]?
    }

    open var deviceIdentifier: String? {
        if let config = self.managedConfig {
            return config["com.AirWatch.mdm.DeviceUid"] as? String
        }

        return nil
    }

    open var locationGroup: String? {
        if let config = self.managedConfig {
            return config["com.AirWatch.mdm.Gid"] as? String
        }

        return nil
    }

    open var airwatchServerURL: String? {
        guard
            let config = self.managedConfig,
            let serverString = config["com.AirWatch.mdm.ServerUrl"] as? String,
            let serverURL = URL(string: serverString.lowercased())
        else {
            return nil
        }
        
        let serverURLString: String
        if serverURL.lastPathComponent == "deviceservices" {
            serverURLString = serverURL.deletingLastPathComponent().absoluteString
        } else {
            serverURLString = serverURL.absoluteString
        }

        if serverURLString.hasSuffix("/") {
            return serverURLString.substring(to: serverURLString.index(before: serverURLString.endIndex))
        }

        return serverURLString
    }

    open var oneTimetoken: String? {
        if let config = self.managedConfig {
            return config["com.Airwatch.mdm.oneTimeToken"] as? String
        }

        return nil
    }
}
