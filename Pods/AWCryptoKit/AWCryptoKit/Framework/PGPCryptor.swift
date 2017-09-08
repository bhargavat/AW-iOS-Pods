//
//  PGPCryptor.swift
//  AWCryptoKit
//
//  Created by Anuj Panwar on 1/20/17.
//  Copyright © 2017 VMware, Inc. All rights reserved.
//

import Foundation
import AWError

public extension AWError.SDK.CryptoKit {
    
    enum PGPCryptor: AWSDKErrorType {
        case SymmetricKeyCreationFailure
        case CorruptedDataFailure
        case PayloadEncryptionFailure
        case PayloadDecryptionFailure
    }
}

struct  CipherHelper : CipherMessage {
    var algorithm: CipherAlgorithm
    var blockMode: BlockCipherMode
    var ivSize: Int
}

fileprivate enum PGPEnvelopeKey: String {
    case Payload      = "Payload"
    case EnryptionKey = "EncryptionKey"
}

fileprivate let PGPCryptorKeySize = 32

public final class PGPCryptor {
    
    public static func encrypt(data: Data, publicKey: SecKey) throws -> Data {
        let encryptionKey = Data.randomData(count: PGPCryptorKeySize)
        
        guard let processedPayload = try CipherHelper.defaultMessage.encrypt(data, key:encryptionKey) else {
            throw AWError.SDK.CryptoKit.PGPCryptor.PayloadEncryptionFailure
        }
        
        let cipherData = try RSACryptor.encrypt(encryptionKey, publicKey: publicKey, padding: .PKCS1)
        
        let dict: [String: Data] = [
            PGPEnvelopeKey.Payload.rawValue:      processedPayload,
            PGPEnvelopeKey.EnryptionKey.rawValue: cipherData
        ]
        
        return  try PropertyListSerialization.data(fromPropertyList: dict,
                                                   format: PropertyListSerialization.PropertyListFormat.binary,
                                                   options: 0)
    }

    public static func decrypt(data: Data, privateKey: SecKey) throws -> Data {
        
        let dict = try PropertyListSerialization.propertyList(from: data,
                                                              options: PropertyListSerialization.ReadOptions(rawValue: 0),
                                                              format: nil) as? [String: Data]
        
        guard let dictionary = dict else {
            throw AWError.SDK.CryptoKit.PGPCryptor.CorruptedDataFailure
        }
        
        guard
            let encryptedSymmetricKey = dictionary[PGPEnvelopeKey.EnryptionKey.rawValue],
            let processedPayload = dictionary[PGPEnvelopeKey.Payload.rawValue]
        else {
            throw AWError.SDK.CryptoKit.PGPCryptor.CorruptedDataFailure
        }
        
        let symmetricKey = try RSACryptor.decrypt(encryptedSymmetricKey, privateKey: privateKey, padding: .PKCS1)
        guard let decryptedData = try CipherHelper.decrypt(processedPayload, key: symmetricKey) else {
            throw AWError.SDK.CryptoKit.PGPCryptor.PayloadDecryptionFailure
        }
        
        return decryptedData
    }
}

