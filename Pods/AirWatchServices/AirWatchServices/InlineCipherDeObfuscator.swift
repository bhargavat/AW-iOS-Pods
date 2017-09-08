//
//  InlineCipherDeObfuscator.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCrypto

protocol InlineCipherDeObfuscator {
    var phrase: String { get }
    var salt: String { get }
    
    @inline(__always)
    func decrypt(_ cipher: String) -> Data?
}

extension InlineCipherDeObfuscator {
    
    @inline(__always)
    func decrypt(_ cipher: String) -> Data? {
        let phraseData = phrase.data(using: String.Encoding.utf8)
        let saltData = salt.data(using: String.Encoding.utf8)
        guard let phraseSha256 = phraseData?.sha256 else {
            return nil
        }
        
        guard let saltSha256 = saltData?.sha256 else {
            return nil
        }
        let encKey = phraseSha256 ^ saltSha256
        
        guard let key = encKey?.sha256 else { return nil }
        let data = Data.base64DecodeData(cipher)
        let decryptData = try? Data.AESDecryptV0(data, key: key, iv: nil)
        return decryptData
    }
}

