//
//  CryptoHelper.swift
//  AWOpenURLClient
//
//  Created by Anuj Panwar on 3/31/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation
import AWCrypto


struct  MessageCryptor: CipherMessage {
    var algorithm: CipherAlgorithm
    var blockMode: BlockCipherMode
    var ivSize: Int
}

struct CryptoHelper {
    
    static let cryptVersion = CipherMessageVersion.V1.rawValue
    let rsaKeyPair:SecurityKeyPair
    var uniqueIdentifier: String
    
    init?(identifier: String) {
        self.uniqueIdentifier = identifier
        do {
            let keyPair = try SecurityKeyPair.generate(1024, identifier: identifier, persistent: false)
            guard
                keyPair.areBothKeysAvailable
                else {
                    log(error: "rsakeypair generation failure")
                    return nil
            }
            self.rsaKeyPair = keyPair
            self.uniqueIdentifier = identifier
        } catch let error {
            log(error: "generating keyPair failed with error: \(error):")
            return nil
        }
    }
    
    
    var encryptionKey: String? {
        guard let publicKey = self.rsaKeyPair.publicKey,
            let publicKeyData = Data.publicKeyData(publicKey)
            else {
                log(error: "encryptionKey generation failure")
                return nil
        }
        return publicKeyData.base64EncodedString()
    }
    
    
    func decryptPayload(encryptedPayload: String) -> String? {
        
        guard let privatekey = self.rsaKeyPair.privateKey,
        let privatekeyData = Data.privateKeyData(privatekey) else {
            log(error: "cannot decrypt, no private key found")
            return nil
        }
        //5.x SDK payload(string) is converted to utf8 data and encrypted
        //the result is then converted to base64encodedString and sent
        guard let decodedData = Data(base64Encoded: encryptedPayload) else {
            log(error: "payload is not in correct format")
            return nil
        }
        
        //try normal decryption first
        guard decodedData.count > SecKeyGetBlockSize(privatekey) else {
            do {
                if let decryptedPayload = try MessageCryptor.decrypt(decodedData, key: privatekeyData) {
                    return  String(data: decryptedPayload, encoding: .utf8)
                }
                log(error: "failed to decrypt payload")
                return nil
            } catch let decryptError {
                log(error: "error decrypting payload:\(decryptError)")
                return nil
            }
        }

        //data exceeds key size, PGP decryption
        do {
            let decryptedPayload = try PGPCryptor.decrypt(data: decodedData, privateKey: privatekey)
            return  String(data: decryptedPayload, encoding: .utf8)
            
        } catch let error {
            log(error: "error decrypting paylaod:\(error)")
        }
        return nil
    }
    
}

