//
//  CryptoHelpers.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWCrypto
import Foundation
import AWError

public extension Data {
    
    public static func AES128Encrypt(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes128, mode: .cbc).encrypt(data, key: key, iv: iv)
        }

        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }

    public static func AES128Decrypt(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes128, mode: .cbc).decrypt(data, key: key, iv: iv)
        }
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }

    public static func AES128EncryptV0(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes128, mode: .ecb).encrypt(data, key: key, iv: iv)
        }
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }

    public static func AES128DecryptV0(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes128, mode: .ecb).decrypt(data, key: key, iv: iv)
        }
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }

}


public extension NSData {
    
    @objc(AW_AES128EncryptedData:key:iv:error:)
    public static func AES128Encrypt(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AES128Encrypt(data as? Data, key: key as? Data, iv: iv as? Data) as NSData
    }
    
    @objc(AW_AES128DecryptedData:key:iv:error:)
    public static func AES128Decrypt(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AES128Decrypt(data as? Data, key: key as? Data, iv: iv as? Data) as NSData
    }
    
    @objc(AW_AES128EncryptedDataV0:key:iv:error:)
    public static func AES128EncryptV0(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AES128EncryptV0(data as? Data, key: key as? Data, iv: iv as? Data) as NSData
    }
    
    @objc(AW_AES128DecryptedDataV0:key:iv:error:)
    public static func AES128DecryptV0(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AES128DecryptV0(data as? Data, key: key as? Data, iv: iv as? Data) as NSData
    }
    
}
