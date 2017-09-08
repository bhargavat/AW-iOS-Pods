//
//  ProxyPayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWTunnel

@objc(AWSDKProxyPayload)
internal class SDKProxyPayload: ProfilePayload, ProxyPayload {

    //TODO::Some of these might not be needed since we are only using  now
    internal fileprivate (set) var proxyType: AWTunnel.ProxyType = .none
    internal fileprivate (set) var redirectTraffic: Bool = false
    internal fileprivate (set) var hostName: String?

    internal fileprivate (set) var httpPort: Int = 0
    internal fileprivate (set) var httpsPort: Int = 0

    //  Settings
    internal fileprivate (set) var publicSSL: Bool = false
    internal fileprivate (set) var f5Integration: Bool = false

    internal fileprivate (set) var f5Port: Int = 0
    internal fileprivate (set) var f5Host: String?
    internal fileprivate (set) var f5UseAuthentication: Bool  = false
    internal fileprivate (set) var f5UserAccountType: Int = 0
    internal fileprivate (set) var f5UserAccountName: String?
    internal fileprivate (set) var f5UserAccountPassword: String?
    internal fileprivate (set) var f5AuthenticationMode: AWTunnel.F5AuthenticationMode = .unknown

    internal fileprivate (set) var appTunnelDomains: NSArray = []
    internal fileprivate (set) var magSSLCertificates: NSArray = []

    // Standard Proxy
    internal fileprivate (set) var standardProxyUseAuth: Bool = false
    internal fileprivate (set) var standardProxyUsername: String?
    internal fileprivate (set) var standardProxyPassword: String?
    internal fileprivate (set) var standardProxyAutoConfig: Bool = false
    internal fileprivate (set) var standardProxyAutoConfigURL: String?
    internal fileprivate (set) var magRSAAdaptiveAuthEnabled: Bool = false

    /// For constructing this payload in UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }
    
    override required internal init(dictionary: [String: Any]) {
        super.init(dictionary: dictionary)
        guard dictionary["PayloadType"] as? String == ProxyPayloadConstants.kProxyPayloadType else {
            log(error: "Failed to get Proxy Payload")
            return
        }

        self.redirectTraffic ??= dictionary.bool(for: ProxyPayloadConstants.kProxyEnableProxy)
        
        if let proxyTypeValue = dictionary.int(for: ProxyPayloadConstants.kProxyType),
           -1 ..< 4 ~= proxyTypeValue,
           let pType = AWTunnel.ProxyType(rawValue: proxyTypeValue)
        {
            self.proxyType = pType
        }
        
        switch proxyType {
        case .mag:
            self.hostName = dictionary[ProxyPayloadConstants.kProxyMAGServerURL] as? String
            self.httpPort ??= dictionary.int(for: ProxyPayloadConstants.kProxyMAGHTTPPort)
            self.httpsPort ??= dictionary.int(for: ProxyPayloadConstants.kProxyMAGHTTPSPort)
            self.publicSSL ??= dictionary.bool(for: ProxyPayloadConstants.kProxyMAGUsePublicSSL)
            self.magSSLCertificates ??= (dictionary[ProxyPayloadConstants.kMAGProxySSLCertificate] as? [AnyObject] as NSArray?)
            self.magRSAAdaptiveAuthEnabled ??= dictionary.bool(for: ProxyPayloadConstants.kProxyMagRSAAdaptiveAuthEnabled)
        case .standard:
            self.hostName = dictionary[ProxyPayloadConstants.kProxyStandardProxyURL] as? String
            self.httpPort ??= dictionary.int(for: ProxyPayloadConstants.kProxyStandardPort)
            self.httpsPort ??= dictionary.int(for: ProxyPayloadConstants.kProxyStandardPort)
            self.standardProxyUseAuth ??= dictionary.bool(for: ProxyPayloadConstants.kProxyStandardUseAuth)
            self.standardProxyUsername = dictionary[ProxyPayloadConstants.kProxyStandardUsername]
                as? String
            self.standardProxyPassword = dictionary[ProxyPayloadConstants.kProxyStandardPassword] as? String
            self.standardProxyAutoConfig ??= dictionary.bool(for: ProxyPayloadConstants.kProxyStandardAutoConfig)
            self.standardProxyAutoConfigURL = dictionary[ProxyPayloadConstants.kProxyStandardURLSource] as? String
        default:
            break
        }

        self.f5Integration ??= dictionary.bool(for: ProxyPayloadConstants.kProxyEnableF5)
        self.f5Port ??= dictionary.int(for: ProxyPayloadConstants.kProxyF5Port)
        self.f5UseAuthentication ??= dictionary.bool(for: ProxyPayloadConstants.kProxyF5UseAuth)
        self.f5UserAccountType ??= dictionary.int(for: ProxyPayloadConstants.kProxyF5AccountType)
        self.f5UserAccountName = dictionary[ProxyPayloadConstants.kProxyF5AccountName] as? String
        self.f5UserAccountPassword = dictionary[ProxyPayloadConstants.kProxyF5AccountPass] as? String

        if let f5ModeValue = dictionary.int(for: ProxyPayloadConstants.kProxyF5AuthMode),
           -2 ..< 3 ~= f5ModeValue
        {
            self.f5AuthenticationMode = AWTunnel.F5AuthenticationMode(rawValue:f5ModeValue)!
        }
        self.f5Host = dictionary[ProxyPayloadConstants.kProxyF5Host] as? String
        
        if let tmpDomains = dictionary[ProxyPayloadConstants.kProxyAppTunnelDomains] as? [String] {
            self.appTunnelDomains = tmpDomains.filter{ $0 != "" } as NSArray
        }
        log(debug: "ProxyPayload Created")
    }

    override internal class func payloadType() -> String {
        return ProxyPayloadConstants.kProxyPayloadType
    }
}
