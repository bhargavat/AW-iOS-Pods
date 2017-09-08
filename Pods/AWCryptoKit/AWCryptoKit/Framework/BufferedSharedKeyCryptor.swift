//
//  BufferedSharedKeyCryptor.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError


public final class BufferedSharedKeyCryptor: SharedKeyCryptor {

    public var cryptor: CCCryptorRef? = nil
    deinit {
        CCCryptorRelease(cryptor)
    }

    fileprivate func start(_ key: Data, iv: Data, encrypting: Bool) throws {
        guard key.count == algorithm.keysize
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.invalidKeyLengthForGivenAlgorithm }

        if self.cryptor != nil {
            CCCryptorRelease(self.cryptor)
            self.cryptor = nil
        }

        let operation = encrypting ? UInt32(kCCEncrypt) : UInt32(kCCDecrypt)
        //Ignoring status relying upon Swift Safety. Parameters to this call should never go wrong. This could not be tested
        
        let status = key.withUnsafeBytes { (keyBytes) -> CCCryptorStatus in
            return iv.withUnsafeBytes { (ivBytes) -> CCCryptorStatus in
             CCCryptorCreate(operation, algorithm.algorithm, cipherMode.options, keyBytes, key.count, ivBytes, &cryptor)
            }
        }
        guard (status == noErr)
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.cryptorStartFailed(status) }

    }

    public func startEncryption(_ key: Data, iv: Data) throws {
        try start(key, iv: iv, encrypting: true)
    }

    public func startDecryption(_ key: Data, iv: Data) throws {
        try start(key, iv: iv, encrypting: false)
    }

    func getOutputBufferForInputLength(_ inputByteCount: Int, isFinal: Bool = false) -> Int {
        return CCCryptorGetOutputLength(self.cryptor, inputByteCount, isFinal)
    }

    public func update(_ data: Data) throws -> Data {

        let availableBytes = getOutputBufferForInputLength(data.count, isFinal: false)
        var outputBuffer = [UInt8](repeating: 0, count: Int(availableBytes))
        var dataOutMoved = 0
        //Ignoring status relying upon Swift Safety. Parameters to this call should never go wrong. This could not be tested
        let status = data.withUnsafeBytes { (dataBytes) -> CCCryptorStatus in
            return CCCryptorUpdate(self.cryptor, dataBytes, data.count, &outputBuffer, availableBytes, &dataOutMoved)
        }

        guard status == noErr
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.updateCryptorWithDataFailed(status) }
        
        return Data(bytes: &outputBuffer, count: dataOutMoved)
    }

    public func finalize() throws -> Data {
        let availableBytes = getOutputBufferForInputLength(0, isFinal: true)
        var outputBuffer = [UInt8](repeating: 0, count: Int(availableBytes))
        var dataOutMoved: Int = 0
        //Ignoring status relying upon Swift Safety. Parameters to this call should never go wrong. This could not be tested
        let status = CCCryptorFinal(self.cryptor, &outputBuffer, availableBytes, &dataOutMoved)
        guard status == noErr
            else { throw AWError.SDK.CryptoKit.SharedKeyCryptor.updateCryptorWithDataFailed(status) }

        return Data(bytes: &outputBuffer, count: dataOutMoved)
    }

}
