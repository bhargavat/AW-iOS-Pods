//
//  Identity.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public class SecureChannelConfiguration: NSObject, NSCoding {

    class CoderKeys {
        static let URLString = "secure-channel.urlstring"
        static let serverCertificate = "secure-channel.server.cert"
        static let clientCertificate = "secure-channel.client.cert"
        static let clientPrivateKey = "secure-channel.client.key"
        static let clientPrivateKeyPassphrase = "secure-channel.client.key.passphrase"
    }
    
    public var URLString: String?
    public var serverCertificate: Data?
    public var clientCertificate: Data?
    public var clientPrivateKey: Data?
    public var clientPrivateKeyPassphrase: String?
    

    @objc required convenience public init(coder decoder: NSCoder) {
        self.init()
        self.URLString = decoder.decodeObject(forKey: SecureChannelConfiguration.CoderKeys.URLString) as? String
        self.serverCertificate = decoder.decodeObject(forKey: SecureChannelConfiguration.CoderKeys.serverCertificate) as? Data
        self.clientCertificate = decoder.decodeObject(forKey: SecureChannelConfiguration.CoderKeys.clientCertificate) as? Data
        self.clientPrivateKey = decoder.decodeObject(forKey: SecureChannelConfiguration.CoderKeys.clientPrivateKey) as? Data
        self.clientPrivateKeyPassphrase = decoder.decodeObject(forKey: SecureChannelConfiguration.CoderKeys.clientPrivateKeyPassphrase) as? String
        
    }

    @objc public func encode(with coder: NSCoder) {

        if let urlstring = URLString {
            coder.encode(urlstring, forKey: SecureChannelConfiguration.CoderKeys.URLString)
        }

        if let serverCertificate = serverCertificate {
            coder.encode(serverCertificate, forKey: SecureChannelConfiguration.CoderKeys.serverCertificate)
        }

        if let clientCertificate = clientCertificate {
            coder.encode(clientCertificate, forKey: SecureChannelConfiguration.CoderKeys.clientCertificate)
        }

        if let clientPrivateKey = clientPrivateKey {
            coder.encode(clientPrivateKey, forKey: SecureChannelConfiguration.CoderKeys.clientPrivateKey)
        }
        
        if let clientPrivateKeyPassphrase = clientPrivateKeyPassphrase {
            coder.encode(clientPrivateKeyPassphrase, forKey: SecureChannelConfiguration.CoderKeys.clientPrivateKeyPassphrase)
        }
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if self === object as? SecureChannelConfiguration { return true }

        var sameURL = false
        var sameServerCertificate = false
        var sameClientCertificate = false
        var sameClientPrivateKey = false
        var sameClientPrivateKeyPassphrase = false

        if let other = object as? SecureChannelConfiguration {
            sameURL = (self.URLString == other.URLString)
            sameServerCertificate = (self.serverCertificate == other.serverCertificate)
            sameClientCertificate = (self.clientCertificate == other.clientCertificate)
            sameClientPrivateKey = (self.clientPrivateKey == other.clientPrivateKey)
            sameClientPrivateKeyPassphrase = (self.clientPrivateKeyPassphrase == other.clientPrivateKeyPassphrase)
        }

        return (sameURL && sameServerCertificate && sameClientCertificate && sameClientPrivateKey && sameClientPrivateKeyPassphrase)
    }
}
