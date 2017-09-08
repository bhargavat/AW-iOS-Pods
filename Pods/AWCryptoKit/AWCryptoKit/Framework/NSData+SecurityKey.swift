//
//  NSData+SecureKey.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


extension Data {

    public static func queryPublicKeyData(_ identifier: String? = nil) -> Data? {
        let query = SecureKeyType.publicKey.dataConversionAttributes(identifier)
        var publicKeyData: AnyObject? = nil
        let qResult = withUnsafeMutablePointer(to: &publicKeyData) {
             SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if qResult != errSecSuccess {
            log(error:"Error retrieving public key data: \(qResult)")
            return nil
        }

        return (publicKeyData as? Data)
    }

    public static func queryPrivateKeyData(_ identifier: String? = nil) -> Data? {
        let query = SecureKeyType.privateKey.dataConversionAttributes(identifier)
        var privateKeyData: AnyObject? = nil
        let qResult = withUnsafeMutablePointer(to: &privateKeyData) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if qResult != errSecSuccess {
            log(error:"Error retrieving private key data: \(qResult)")
            return nil
        }

        return (privateKeyData as? Data)
    }

    public static func privateKeyData(_ privateKey: SecKey) -> Data? {
        let identifier = UUID().uuidString
        var attributes = SecureKeyType.privateKey.dataConversionAttributes(identifier)
        attributes[String(kSecValueRef)] = privateKey

        var dataRef: AnyObject?
        let status = SecItemAdd( attributes as CFDictionary, &dataRef)
        if(status != noErr) {
           log(error:"Error converting private SecKey to Data:\(status)")
            dataRef = nil
        }

        defer {
            SecItemDelete(attributes as CFDictionary)
        }

        return dataRef as? Data
    }

    public static func publicKeyData(_ publicKey: SecKey) -> Data? {
        let identifier = UUID().uuidString
        var attributes = SecureKeyType.publicKey.dataConversionAttributes(identifier)
        attributes[String(kSecValueRef)] = publicKey

        var dataRef: AnyObject?
        let status = SecItemAdd( attributes as CFDictionary, &dataRef)
        if(status != noErr) {
            log(error:"Error converting public SecKey to Data:\(status)")
            dataRef = nil
        }

        defer {
            SecItemDelete(attributes as CFDictionary)
        }

        return dataRef as? Data
    }

    //NSData to SecKey conversions
    public static func secKeyRefFromPublicKeyData(_ publicKeyData: Data) -> SecKey? {

        let identifier = UUID().uuidString
        var attributes = SecureKeyType.publicKey.referenceConversionAttributes(identifier)
        defer {
            SecItemDelete(attributes as CFDictionary)
        }

        if #available(iOS 10, *) {
            let secKey = SecKeyCreateWithData(publicKeyData as CFData, attributes as CFDictionary, nil)
            if secKey == nil {
                log(error:"Error converting public key data into SecKey")
            }
            return secKey
        }
        
        attributes[String(kSecValueData)] = publicKeyData as CFData
        var publicKey: AnyObject? = nil
        let status = SecItemAdd(attributes as CFDictionary, &publicKey)
        guard status == noErr else {
            log(error:"Error converting public key data into SecKey: \(status)")
            return nil
        }
        
        return (publicKey as! SecKey)
    }

    public static func secKeyRefFromPrivateKeyData(_ privateKeyData: Data) -> SecKey? {
        let identifier = UUID().uuidString
        var attributes = SecureKeyType.privateKey.referenceConversionAttributes(identifier)
        defer {
            SecItemDelete(attributes as CFDictionary)
        }
        
        if #available(iOS 10, *) {
            let secKey = SecKeyCreateWithData(privateKeyData as CFData, attributes as CFDictionary, nil)
            if secKey == nil {
                log(error:"Error converting public key data into SecKey")
            }
            return secKey
        }
        
        attributes[String(kSecValueData)] = privateKeyData as CFData
        var privateKey: AnyObject? = nil
        let status = SecItemAdd(attributes as CFDictionary, &privateKey)
        guard status == noErr else {
            log(error:"Error converting private key data into SecKey: \(status)")
            return nil
        }
        return (privateKey as! SecKey)
    }

}
