//
//  SessionKeyStore.swift
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

protocol CryptKeyMaker: DataStoreItemQueryProvider, PassphraseDerivator {
    var datastore: AbstractKeyValueStore { get set }
    func cryptKeyWithPin(_ pin: String) -> Data?

    func getCryptKeySalt() -> Data?

    mutating func createCryptKeySalt() -> Data

}


extension CryptKeyMaker {

    mutating func createCryptKeySalt() -> Data {
        let randomSalt = self.generateSalt(32)
        if self.datastore.set(itemQueryProvider.CryptKeySalt, value: randomSalt) {
            return randomSalt
        }

        //Existing implementation's default salt.
        return "MTE!F^&fb-".data(using: String.Encoding.utf8)!
    }

    func getCryptKeySalt() -> Data? {
        let ret: Data? = self.datastore.fetch(itemQueryProvider.CryptKeySalt)
        log(debug: "Requesting from datastore(\(datastore)) the CryptKeySalt: \(ret?.hexadecimalString ?? "Data is nil")")
        return ret
    }

    func cryptKeyWithPin(_ pin: String) -> Data? {

        let cryptKeySalt = self.getCryptKeySalt()
        if cryptKeySalt == nil {
            log(error: "Crypt Key salt missing. Problem?? lurking??")
            log(error: "Will move ahead with standard salt")
        }

        if  let finalSalt = cryptKeySalt ?? "MTE!F^&fb-".data(using: String.Encoding.utf8),
            let saltData = finalSalt.hexadecimalString.data(using: String.Encoding.utf8) {
            do {
                let finalKey = try self.deriveKey(pin, saltData: saltData)
                return finalKey
            } catch {
                log(error: "Failed to derive Crypt key with entered pin and random salt")
            }
        }
        
        return nil
    }
}

struct CryptKeyProvider: CryptKeyMaker {
    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var datastore: AbstractKeyValueStore
}
