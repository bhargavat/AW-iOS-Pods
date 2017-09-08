//
//  EncryptionHelper.swift
//  AWSecureSharedStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCrypto
import AWStorage


public struct SimpleKeyCryptor: StoreCryptor {
    let key: Data
    public func encryptObject<T: DataRepresentable>(_ object: T?) -> Data? {
        return SecureDataMessage.defaultMessage.encryptObject(object, key: key)
    }

    public func decryptObject<T: DataRepresentable>(_ data: Data?) -> T? {
        return SecureDataMessage.decryptObject(data, key: key)
    }
}



struct  SecureDataMessage: CipherMessage {
    var algorithm: CipherAlgorithm
    var blockMode: BlockCipherMode
    var ivSize: Int

    func encryptObject<T: DataRepresentable>(_ object: T?, key: Data) -> Data? {
        guard let data = object?.toData() else { return nil }

        do {
            return try self.encrypt(data, key: key)
        } catch {
            log(debug: "Enryption failed for object: \(String(describing: object)) with Key: \(key)")
        }

        return nil
    }

    static func decryptObject<T: DataRepresentable>(_ data: Data?, key: Data) -> T? {

        guard let cipherData = data else { return nil }

        do {
            if let objectData = try SecureDataMessage.decrypt(cipherData, key: key) {
                return T.fromData(objectData)
            }
        } catch {
            log(debug: "Decrypted failed for data: \(String(describing: data)) with Key: \(key)")
        }

        return nil
    }
}
