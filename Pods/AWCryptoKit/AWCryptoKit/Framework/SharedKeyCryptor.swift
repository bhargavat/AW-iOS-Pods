//
//  SharedKeyCryptor.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError


open class SharedKeyCryptor {

    internal let algorithm: CipherAlgorithm
    internal let cipherMode: BlockCipherMode

    open static func defaultCryptor() -> SharedKeyCryptor {
        return SharedKeyCryptor(algorithm: CipherAlgorithm.aes256, mode: BlockCipherMode.cbc)
    }

    public init(algorithm: CipherAlgorithm, mode: BlockCipherMode) {
        self.algorithm = algorithm
        self.cipherMode = mode
    }

    /**
     
     @throws AWError.SDK.Hardware.outOfMemory if the system cannot allocate a temporary buffer
     @throws AWError.SDK.CryptoKit.SharedKeyCryptor.encryptionFailed(status) an error occured from CCCrypt
     @throws AWError.SDK.CryptoKit.SharedKeyCryptor.invalidKeyLengthForGivenAlgorithm if size of key does not match the algorithm size
     */
    public final func encrypt(_ data: Data, key: Data, iv: Data?) throws -> Data {
        guard key.count == algorithm.keysize
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.invalidKeyLengthForGivenAlgorithm }

        let bufferSize = data.count + algorithm.blockSize
        guard var buffer = malloc(bufferSize)
            else { throw AWError.SDK.Hardware.outOfMemory }
        defer {
            free(buffer)
        }
        var bytesCount = 0
        let ivData = iv != nil ? iv! : Data()
        
        let status = CCCrypt(UInt32(kCCEncrypt),
                             algorithm.algorithm,
                             cipherMode.options,
                             (key as NSData).bytes, key.count,
                             (ivData as NSData).bytes,
                             (data as NSData).bytes, data.count,
                             buffer, bufferSize,
                             &bytesCount)

        guard status == noErr
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.encryptionFailed(status) }

        return Data(bytes: buffer, count: bytesCount)
    }
    /**
     
     @throws AWError.SDK.Hardware.outOfMemory if the system cannot allocate a temporary buffer
     @throws AWError.SDK.CryptoKit.SharedKeyCryptor.decryptionFailed(status) an error occured from CCCrypt
     @throws AWError.SDK.CryptoKit.SharedKeyCryptor.invalidKeyLengthForGivenAlgorithm if size of key does not match the algorithm size
     */
    public final func decrypt(_ data: Data, key: Data, iv: Data?) throws -> Data {
        guard key.count == algorithm.keysize
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.invalidKeyLengthForGivenAlgorithm }

        let bufferSize = data.count + algorithm.blockSize
        guard var buffer = malloc(bufferSize)
            else { throw AWError.SDK.Hardware.outOfMemory }
        defer {
            free(buffer)
        }
        var bytesCount = 0
        let ivData = iv != nil ? iv! : Data()
        
        let status = CCCrypt(UInt32(kCCDecrypt),
                             algorithm.algorithm,
                             cipherMode.options,
                             (key as NSData).bytes, key.count,
                             (ivData as NSData).bytes,
                             (data as NSData).bytes, data.count,
                             buffer, bufferSize, &bytesCount)

        guard status == noErr
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.decryptionFailed(status) }

        return Data(bytes: buffer, count: bytesCount)
    }

    open func isEqual(_ object: Any?) -> Bool {

        if let rhs = object as? SharedKeyCryptor {
            return ((algorithm == rhs.algorithm) && (cipherMode == rhs.cipherMode))
        }

        return false
    }

}

public func == (lhs: SharedKeyCryptor, rhs: SharedKeyCryptor) -> Bool {
   return ((lhs.algorithm == rhs.algorithm) && (lhs.cipherMode == rhs.cipherMode))
}


public extension Data {
    
    public static func AESEncrypt(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes256, mode: .cbc).encrypt(data, key: key, iv: iv)
        }
        
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }
    
    public static func AESDecrypt(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes256, mode: .cbc).decrypt(data, key: key, iv: iv)
        }
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }
    
    public static func AESEncryptV0(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes256, mode: .ecb).encrypt(data, key: key, iv: iv)
        }
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }
    
    public static func AESDecryptV0(_ data: Data?, key: Data?, iv: Data?) throws -> Data {
        if let data = data, let key = key {
            return try SharedKeyCryptor(algorithm: .aes256, mode: .ecb).decrypt(data, key: key, iv: iv)
        }
        throw AWError.SDK.CryptoKit.SharedKeyCryptor.incompleteData
    }
    
}

public extension NSData {

    @objc(AW_AESEncryptedData:key:iv:error:)
    public static func AESEncrypt(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AESEncrypt(data as Data?, key: key as Data?, iv: iv as Data?) as NSData
    }

    @objc(AW_AESDecryptedData:key:iv:error:)
    public static func AESDecrypt(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AESDecrypt(data as Data?, key: key as Data?, iv: iv as Data?) as NSData
    }

    @objc(AW_AESEncryptedDataV0:key:iv:error:)
    public static func AESEncryptV0(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AESEncryptV0(data as Data?, key: key as Data?, iv: iv as Data?) as NSData
    }

    @objc(AW_AESDecryptedDataV0:key:iv:error:)
    public static func AESDecryptV0(_ data: NSData?, key: NSData?, iv: NSData?) throws -> NSData {
        return try Data.AESDecryptV0(data as Data?, key: key as Data?, iv: iv as Data?) as NSData
    }

}
