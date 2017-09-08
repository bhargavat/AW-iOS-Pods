//
//  Protocols.swift
//  AWTunnel
//
//  Created by Kishore Sajja on 5/5/17.
//  Copyright © 2017 VMWare, Inc. All rights reserved.
//

import Foundation

@objc
public final class AWTunnel: NSObject {

    @objc(AWProxyType)
    public enum ProxyType: Int, CustomStringConvertible {
        case none = 0
        case mag = 1
        case f5 = 2
        case standard = 3
        
        public var description : String {
            switch self {
            case .none:
                return "None"
                
            case .mag:
                return "MAG"
                
            case .f5:
                return "F5"
                
            case .standard:
                return "Standard"
                
            }
        }

    }

    @objc(AWF5AuthenticationMode)
    public enum F5AuthenticationMode: Int, CustomStringConvertible {
        case unknown = -1
        case usernamePasswordAndCertificate = 0
        case usernameAndPassword = 1
        case certificate = 2
        
        public var description : String {
            switch self {
            case .unknown:
                return "Unknown"
                
            case .usernamePasswordAndCertificate:
                return "UsernamePasswordAndCertificate"
                
            case .usernameAndPassword:
                return "UsernameAndPassword"
                
            case .certificate:
                return "Certificate"
                
            }
        }
        
    }

    @objc(AWContentFilterServerType)
    public enum ContentFilterServerType: Int, CustomStringConvertible {
        case unknown = -1
        case webSense = 0
        
        public var description : String {
            switch self {
            case .unknown:
                return "Unknown"
                
            case .webSense:
                return "WebSense"
            }
        }
    }
}

@objc(AWProfilePayload)
public protocol ProfilePayload: NSObjectProtocol {
    init(dictionary: [String: Any])
    static func payloadType() -> String
    func toDictionary() -> [String: Any]
}

@objc(AWProxyPayload)
public protocol ProxyPayload: ProfilePayload {

    static func payloadType() -> String

    //TODO::Some of these might not be needed since we are only using  now
    var proxyType: AWTunnel.ProxyType { get }
    var redirectTraffic: Bool { get }
    var hostName: String? { get }

    var httpPort: Int { get }
    var httpsPort: Int { get }

    //  Settings
    var publicSSL: Bool { get }
    var f5Integration: Bool { get }

    var f5Port: Int { get }
    var f5Host: String? { get }
    var f5UseAuthentication: Bool { get }
    var f5UserAccountType: Int { get }
    var f5UserAccountName: String? { get }
    var f5UserAccountPassword: String? { get }
    var f5AuthenticationMode: AWTunnel.F5AuthenticationMode { get }

    var appTunnelDomains: NSArray  { get }
    var magSSLCertificates: NSArray { get }

    // Standard Proxy
    var standardProxyUseAuth: Bool { get }
    var standardProxyUsername: String? { get }
    var standardProxyPassword: String? { get }
    var standardProxyAutoConfig: Bool { get }
    var standardProxyAutoConfigURL: String? { get }
    var magRSAAdaptiveAuthEnabled: Bool { get }

}

@objc(AWCertificatePayload)
public protocol CertificatePayload: ProfilePayload {
    var certificateData: Data? { get }
    var certificateName: String? { get }
    var certificatePassword: String? { get }
    var certificateThumbprint: String? { get }
    var certificateType: String? { get }
}

@objc(AWContentFilteringPayload)
public protocol ContentFilteringPayload: ProfilePayload {
    var contentFilterType: AWTunnel.ContentFilterServerType { get }
    var contentFilterProxyId: Int { get }
    var websensePacAddress: String? { get }
    var websenseAccountId: Int { get }
    var websenseSecurityKey: String? { get }
    var websenseProxyId: Int { get }
}
