//
//  RSACryptor.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import Security
import AWError


public final class RSACryptor {
    public let keyPair: SecurityKeyPair


    public init?(keyPair: SecurityKeyPair) {
        guard !keyPair.isEmpty else {return nil}
        self.keyPair = keyPair
    }

    public func encrypt(_ data: Data) throws -> Data {
        guard keyPair.publicKey != nil
            else { throw AWError.SDK.CryptoKit.RSACryptor.missingPublicKey }

        return try RSACryptor.encrypt(data, publicKey: keyPair.publicKey!, padding: keyPair.padding)
    }

    public func decrypt(_ data: Data) throws -> Data {
        guard keyPair.privateKey != nil
            else { throw AWError.SDK.CryptoKit.RSACryptor.missingPrivateKey }

        return try RSACryptor.decrypt(data, privateKey: keyPair.privateKey!, padding: keyPair.padding)
    }

    public func sign(_ data: Data) throws -> Data {
        guard keyPair.privateKey != nil
            else { throw AWError.SDK.CryptoKit.RSACryptor.missingPrivateKey }

        return try RSACryptor.sign(data, privateKey: keyPair.privateKey!, padding: keyPair.padding)
    }

    public func verify(_ signedData: Data, signature: Data) throws -> Bool {
        guard keyPair.publicKey != nil
            else { throw AWError.SDK.CryptoKit.RSACryptor.missingPublicKey }

        return try RSACryptor.verify(signedData, signature: signature, publicKey: keyPair.publicKey!, padding: keyPair.padding)
    }


    public static func encrypt(_ data: Data, publicKey: SecKey, padding: SecPadding) throws -> Data {
        var cipherBufferSize = SecKeyGetBlockSize(publicKey)
        var cipherBuffer = [UInt8](repeating: 0x00, count: cipherBufferSize)
        
        let status = data.withUnsafeBytes { (dataBytes) -> OSStatus in
            SecKeyEncrypt(publicKey, padding, dataBytes, data.count, &cipherBuffer, &cipherBufferSize)
        }
        
        if status != errSecSuccess {
            throw AWError.SDK.CryptoKit.RSACryptor.encryptionFailed(status)
        }

        return Data(bytes: cipherBuffer)
    }

    public static func decrypt(_ data: Data, privateKey: SecKey, padding: SecPadding) throws -> Data {
        var plainTextBufferSize = SecKeyGetBlockSize(privateKey)
        var plainText = [UInt8](repeating: 0x00, count: plainTextBufferSize)
        let status = data.withUnsafeBytes { (dataBytes) -> OSStatus in
            return SecKeyDecrypt(privateKey, padding, dataBytes, data.count, &plainText, &plainTextBufferSize)
        }
        
        if status != errSecSuccess {
            throw AWError.SDK.CryptoKit.RSACryptor.decryptionFailed(status)
        }

        return Data(bytes: plainText).subdata(in: 0..<plainTextBufferSize)
    }

    public static func sign(_ data: Data, privateKey: SecKey, padding: SecPadding) throws -> Data {
        var signatureBufferSize = SecKeyGetBlockSize(privateKey)
        var signature = [UInt8](repeating: 0x00, count: signatureBufferSize)
        let status = data.withUnsafeBytes { (dataBytes) -> OSStatus in
            return SecKeyRawSign(privateKey, padding, dataBytes, data.count, &signature, &signatureBufferSize)
        }
        if status != errSecSuccess {
            throw AWError.SDK.CryptoKit.RSACryptor.dataSigningFailed(status)
        }
        return Data(bytes: signature).subdata(in: 0..<signatureBufferSize)
    }

    public static func verify(_ signedData: Data, signature: Data, publicKey: SecKey, padding: SecPadding) throws -> Bool {
        
        let status = signedData.withUnsafeBytes { (signedDataBytes) -> OSStatus in
            return signature.withUnsafeBytes{ (signatureBytes) -> OSStatus in
                return SecKeyRawVerify(publicKey, padding, signedDataBytes, signedData.count, signatureBytes, signature.count)
            }
        }

        if status != errSecSuccess {
            throw AWError.SDK.CryptoKit.RSACryptor.signatureVerificationFailed(status)
        }

        return true
    }
}
