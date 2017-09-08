//
//  HMAC.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


extension Digest {

    var hmacAlgorithm: UInt32 {
        switch self {
        case .md5:
            return UInt32(kCCHmacAlgMD5)

        case .sha1:
            return UInt32(kCCHmacAlgSHA1)

        case .sha256:
            return UInt32(kCCHmacAlgSHA256)

        case .sha512:
            return UInt32(kCCHmacAlgSHA512)
        }
    }

    public func hmacSignature(_ data: Data, withKey key: Data) -> Data {
        var digest = [UInt8](repeating: 0x00, count: Int(digestLength) )

        key.withUnsafeBytes { (keyBytes) -> Void in
            data.withUnsafeBytes { (dataBytes) -> Void in
                CCHmac(self.hmacAlgorithm, keyBytes, key.count, dataBytes, data.count, &digest)
            }
        }
        
        return Data(bytes: digest)
    }

}

extension Data {

    public func sign(_ algorithm: Digest, key: Data) -> Data {
        return algorithm.hmacSignature(self, withKey: key)
    }

    public func base64HMACSignature(_ algorithm: Digest, key: Data) -> String {
        let hmacData = algorithm.hmacSignature(self, withKey: key)
        return hmacData.base64EncodedString(options: .lineLength64Characters)
    }
}


extension NSData {
    
    public func sign(_ algorithm: Digest, key: NSData) -> NSData {
        return algorithm.hmacSignature(self as Data, withKey: key as Data) as NSData
    }
    
    public func base64HMACSignature(_ algorithm: Digest, key: Data) -> String {
        let hmacData = algorithm.hmacSignature(self as Data, withKey: key as Data)
        return hmacData.base64EncodedString(options: .lineLength64Characters)
    }
}


