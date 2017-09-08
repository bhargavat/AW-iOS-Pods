//
//  NetworkAccessPayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


extension AWSDK {
    @objc(AWNetworkAccessAllowCellular)
    public enum AllowCellularNetworkAccess: Int {
        case never = 0
        case always = 1
        case notRoaming = 2
    }

    @objc(AWNetworkAccessAllowWiFi)
    public enum AllowWiFiNetworkAccess: Int {
        case always = 1
        case filter = 2
    }
}

@objc(AWNetworkAccessPayload)
public class NetworkAccessPayload: ProfilePayload {
    public private (set) var enableNetworkAccess: Bool = false
    public private (set) var allowCellularConnection: AWSDK.AllowCellularNetworkAccess = .always
    public private (set) var allowWifiConnection: AWSDK.AllowWiFiNetworkAccess = .always
    public private (set) var allowedSSIDs: [String]

    /// For constructing this payload in UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String: Any]) {
        self.allowedSSIDs = []
        super.init(dictionary: dictionary)
        
        self.enableNetworkAccess ??= dictionary.bool(for: NetworkAccessPayloadConstants.kNetworkAccessEnabled)
        
        if let shouldAllowCellularConnectionIntValue = dictionary.int(for: NetworkAccessPayloadConstants.kNetworkAccessAllowCellular),
           let allowCelluarConnection = AWSDK.AllowCellularNetworkAccess(rawValue:shouldAllowCellularConnectionIntValue) {
            self.allowCellularConnection = allowCelluarConnection
        }
        
        if let shouldAllowWifiIntValue = dictionary.int(for: NetworkAccessPayloadConstants.kNetworkAccessAllowWiFi),
           let shouldAllowWifi = AWSDK.AllowWiFiNetworkAccess(rawValue:shouldAllowWifiIntValue) {
            self.allowWifiConnection = shouldAllowWifi
        }

        if let profileSSIDs = dictionary[NetworkAccessPayloadConstants.kNetworkAccessAllowedSSIDs] as? [String] {
            self.allowedSSIDs = profileSSIDs
        }
    }

    override public class func payloadType() -> String {
        return NetworkAccessPayloadConstants.kNetworkAccessPayloadType
    }
}
