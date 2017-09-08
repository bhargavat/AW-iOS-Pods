//
//  AWCipheredData.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import Security

/**
 Enumeration to provide and understand different encryption methods used in
 encoding

 - V0: Initial Version(No Encryption) == AES256ECBNoIV
 - V1: First Version AES256 CBC Encryption == AES256CBCWithIV
 - V2: AES128 with no IV included in header. AES256CBCNoIV
 - V3: AES128 with IV included in header. == AES128CBCWithIV
 */
public enum CipherMessageVersion: String {
    case V0 = "AW0000"
    case V1 = "AW0001"
    case V2 = "AW0002"
    case V3 = "AW0003"
}

public protocol CipherMessage {
    var algorithm: CipherAlgorithm { get }
    var blockMode: BlockCipherMode { get }
    var ivSize: Int { get }

    var options: CCOptions { get }
    var cryptoEngine: SharedKeyCryptor { get }

    static var defaultMessage: Self { get }
    static var V0Message: Self { get }

    static var AES256ECBNoIV: Self { get }
    static var AES256CBCWithIV: Self { get }
    static var AES256CBCNoIV: Self { get }
    static var AES128CBCWithIV: Self { get }

    init(algorithm: CipherAlgorithm, blockMode: BlockCipherMode, ivSize: Int)

    func encrypt(_ data: Data, key: Data) throws -> Data?
    static func decrypt(_ data: Data, key: Data) throws -> Data?
}

public extension CipherMessage {
    var options: CCOptions {
        if self.blockMode == .ecb {
            return UInt32(kCCOptionPKCS7Padding | kCCOptionECBMode)
        }

        return UInt32(kCCOptionPKCS7Padding)
    }

    var cryptoEngine: SharedKeyCryptor {
        return SharedKeyCryptor(algorithm: algorithm, mode: blockMode)
    }

    static var defaultMessage: Self {
        return Self(algorithm: .aes256, blockMode: .cbc, ivSize: kCCKeySizeAES256)
    }

    static var V0Message: Self {
        return Self(algorithm: .aes256, blockMode: .ecb, ivSize: 0)
    }

    static var AES256ECBNoIV: Self {
        return Self(algorithm: .aes256, blockMode: .ecb, ivSize: 0)
    }

    static var AES256CBCWithIV: Self {
        return Self(algorithm: .aes256, blockMode: .cbc, ivSize: kCCKeySizeAES256)
    }

    static var AES256CBCNoIV: Self {
        return Self(algorithm: .aes256, blockMode: .cbc, ivSize: 0)
    }
    static var AES128CBCWithIV: Self {
        return Self(algorithm: .aes128, blockMode: .cbc, ivSize: kCCBlockSizeAES128)
    }

    static func decrypt(_ data: Data, key: Data) throws -> Data? {
        let (version, ivData, payload) = self.parse(data)
        if let payload = payload {
            return try version.cryptoEngine.decrypt(payload, key: key, iv: ivData)
        }
        throw AWError.SDK.CryptoKit.Format.invalidPayloadFormatError
    }

    func encrypt(_ data: Data, key: Data) throws -> Data? {
        var cipheredData = Data()
        var iv: Data? = nil
        if let headerData = self.cryptoFormatString()?.data(using: String.Encoding.utf8) {
            cipheredData.append(headerData)
            let bytes: [UInt8] = [0, 0]
            cipheredData.append(contentsOf: bytes)
            if self.ivSize > 0 {
                iv = Data.randomData(count: self.ivSize)
                cipheredData.append(iv!)
            }
        }
        let payload = try self.cryptoEngine.encrypt(data, key: key, iv: iv)
        cipheredData.append(payload)
        return cipheredData
    }
}

internal extension CipherMessage {
    //Returns the algorithm, IV, and payload
    static func parse(_ data: Data) -> (Self, Data?, Data?) {
        let (version, remainingData) = parseVersion(data)
        let (ivData, payloadData) = version.parseIV(remainingData)
        return (version, ivData, payloadData)
    }

    func parseIV(_ data: Data) -> (Data?, Data?) {
        let ivSize = self.ivSize
        let dataSize = data.count
        
        guard ivSize != 0 else {
            return (nil, data)
        }

        guard dataSize >= ivSize else {
            return (nil, data)
        }
        
        return (Data(data.dropLast(dataSize-ivSize)), Data(data.dropFirst(ivSize)))
    }

    static func parseVersion(_ data: Data) -> (Self, Data) {
        
        guard data.count > 8 else {
            return (Self.AES256ECBNoIV, data)
        }

        guard let versionString = String(data: data.subdata(in: 0..<6), encoding: .utf8) else {
            return (Self.AES256ECBNoIV, data)
        }

        guard let version = cryptoFormatFromString(versionString) else{
            return (Self.AES256ECBNoIV, data)
        }
        
        return (version, Data(data.dropFirst(8)))
        
    }

    static func cryptoFormatFromString(_ format: String) -> Self? {
        if let version = CipherMessageVersion(rawValue: format) {
            switch version {
            case .V1: return self.AES256CBCWithIV
            case .V2: return self.AES256CBCNoIV
            case .V3: return self.AES128CBCWithIV
            default: return nil
            }
        }
        return nil
    }

    func cryptoFormatString() -> String? {

        if self.algorithm == .aes256 &&
            self.blockMode == .cbc &&
            self.ivSize != 0 {
            return CipherMessageVersion.V1.rawValue
        }

        if (self.algorithm == .aes256 &&
            self.blockMode == .cbc &&
            self.ivSize == 0) {
            return CipherMessageVersion.V2.rawValue
        }

        if (self.algorithm == .aes128 &&
            self.blockMode == .cbc &&
            self.ivSize != 0) {
            return CipherMessageVersion.V3.rawValue
        }
        return nil //"AW0000"
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.algorithm == rhs.algorithm
        && lhs.blockMode == rhs.blockMode
        && lhs.ivSize == rhs.ivSize
    }
}
