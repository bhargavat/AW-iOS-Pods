//
//  NSData+Crypto.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension Data {
    public static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0x00, count: count)
        let _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes: bytes, count: count)
    }
}

extension NSData {
    
    public convenience init(randomBytesLength: size_t) {
        var bytes = [UInt8](repeating: 0x00, count: randomBytesLength)
        let _ = SecRandomCopyBytes(kSecRandomDefault, randomBytesLength, &bytes)
        self.init(bytes: bytes, length: randomBytesLength)
    }
    
}
