//
//  LegacySecureChannel.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

// MARK: Legacy Secure Channel Protocols
public protocol LegacySecureChannelStorageProtocol {
    
    // Returns the server certificate
    func serverCertificate(hostname: String) -> Data?
    
    // Returns the private certificate
    func privateKey(hostname: String) -> Data?
    
    // Returns the public certificate
    func publicKey(hostname: String) -> Data?
}

public class Pre17LegacySecureChannelStorage: LegacySecureChannelStorageProtocol {
    // Query used for SDK. This query is split into three functions in pre17.1 for the different keys (public/private/server). Here we bring them into one
    private func query(identifier: String, comTag: String) -> [String: AnyObject] {
        var ret: [String: AnyObject] = [:]
        var tagData = Data()
        if identifier != "" {
            let tag = comTag + "," + identifier
            ret[String(kSecAttrLabel)] = identifier as AnyObject
            if let data = tag.toData() {
                tagData = data
            }
        } else {
            if let data = comTag.toData() {
                tagData = data
            }
        }
        
        ret[String(kSecAttrApplicationTag)] = tagData as AnyObject
        ret[String(kSecAttrApplicationLabel)] = Bundle.main.bundleIdentifier as AnyObject?
        ret[String(kSecClass)] = kSecClassKey
        
        return ret
    }
    
    /**
     @param hostname Look this up in keychain for the server key
     @return Data object for the server key which is in PKCS8. nil is returned if there is no value in keychain for hostname
     */
    public func serverCertificate(hostname: String) -> Data? {
        var query = self.query(identifier: hostname, comTag: "com.server")
        query[String(kSecReturnData)] = true as AnyObject?
        
        var data: AnyObject? = nil
        let result = SecItemCopyMatching(query as CFDictionary, &data)
        if result != noErr {
            log(error: "Could not find server certificate in legacy location for \(hostname)")
            return nil
        }
        
        return data as? Data
    }
    
    /**
     @param hostname Look this up in keychain for the private key
     @param newPassphrase The new passphrase to use for the DER
     @return New Data object for the private key which is in PKCS8. nil is returned if there is no value in keychain for hostname
     */
    public func privateKey(hostname: String) -> Data? {
        var query = self.query(identifier: hostname, comTag: "com.private")
        query[String(kSecReturnData)] = true as AnyObject?
        
        var data: AnyObject? = nil
        let result = SecItemCopyMatching(query as CFDictionary, &data)
        if result != noErr {
            log(error: "Could not find private certificate in legacy location for \(hostname)")
            return nil
        }
        
        return data as? Data
    }
    
    /**
     @param hostname Look this up in keychain for the public key
     @return Data object for the public key which is in PKCS8. nil is returned if there is no value in keychain for hostname
     */
    public func publicKey(hostname: String) -> Data? {
        var query = self.query(identifier: hostname, comTag: "com.public")
        query[String(kSecReturnData)] = true as AnyObject?
        
        var data: AnyObject? = nil
        let result = SecItemCopyMatching(query as CFDictionary, &data)
        if result != noErr {
            log(error: "Could not find public certificate in legacy location for \(hostname)")
            return nil
        }
        
        return data as? Data
    }
}

fileprivate extension String {
    func toData() -> Data? {
        return self.data(using: String.Encoding.utf8)
    }
}
