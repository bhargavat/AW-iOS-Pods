//
//  ServicesConfiguration.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public protocol DeviceServicesConfiguration {
    var airWatchServerURL: String { get }
    var organizationGroup: String { get }
    var deviceId: String { get }
    var deviceType: String { get }
    var bundleId: String { get }
}

/**
 SecureChannelConfigurationManager provides centralized place/APIs to access
 security properties relevant to Secure Channel. It should ensure synchronized
 access to the underlying security storage if needed.
 */
public protocol SecureChannelConfigurationManager {
    
    func secureChannelURL(forHost hostname: String) -> URL?
    func setSecureChannelURL(forHost hostname: String, channelURL: URL)

    func secureChannelServerCertificate(forHost hostname: String) -> Data?
    func setSecureChannelServerCertificate(forHost hostname: String, unverifiedServerCertificateData: Data) throws -> Void

    func secureChannelClientCertificate(forHost hostname: String) -> Data
    func secureChannelClientPrivateKey(forHost hostname: String) -> Data
    
    func secureChannelClientPrivateKeyPassphrase(forHost hostname: String) -> String?

    func resetClientCredentials(forHost hostname: String) -> Void
    func clearAll()
}
