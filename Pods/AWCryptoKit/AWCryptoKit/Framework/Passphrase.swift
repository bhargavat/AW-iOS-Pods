//
//  Passphrase.swift
//  AWCryptoKit
//
//  Created by Kishore Sajja on 6/10/16.
//  Copyright © 2016 VMware, Inc. All rights reserved.
//

import Foundation
import AWError


public protocol PassphraseDerivator {
    
    var KeyLength: Int { get }
    
    func generateSalt(_ lengthInBytes: Int) -> Data
    func deriveKey(_ passcode: String, saltData: Data) throws -> Data
    func deriveKey(_ passcode: String) throws -> (Data, Data)
}

public extension PassphraseDerivator {
    
    var KeyLength: Int { return 32 }

    func generateSalt(_ length: Int) -> Data {
        return Data.randomData(count: length)
    }


    func deriveKey(_ passcode: String, saltData: Data) throws -> Data {
        var passcodeBytes = passcode.utf8.map{ Int8(bitPattern: $0) }
        var saltBytes = [UInt8](repeating: 0x00, count: saltData.count)
        saltData.copyBytes(to: &saltBytes, count: saltBytes.count)

        var derivedKey = [UInt8](repeating: 0, count: KeyLength)
       let status = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), &passcodeBytes, passcodeBytes.count, &saltBytes, saltBytes.count,
                                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 10000, &derivedKey, derivedKey.count)
        guard status == noErr
            else { throw AWError.SDK.CryptoKit.Passphrase.keyDerivationFailed(status) }

        return Data(bytes: UnsafePointer<UInt8>(derivedKey), count: KeyLength)
    }

    func deriveKey(_ passcode: String) throws -> (Data, Data) {
        let saltLength = 36 //Replacing necessity for using GUID bytes.
        let randomData = generateSalt(saltLength)
        let saltData = randomData.hexString.data(using: String.Encoding.utf8)!
        let derivedKey = try deriveKey(passcode, saltData: saltData)
        return (derivedKey, randomData)

    }
}
