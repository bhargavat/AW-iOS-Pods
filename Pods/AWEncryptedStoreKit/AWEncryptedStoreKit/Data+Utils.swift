//
//  Data+Random.swift
//  AWEncryptedStoreKit
//
//  Created by Stephen Turner on 6/20/17.
//  Copyright © 2017 vmware. All rights reserved.
//

import Foundation

extension Data {
    internal static func randomData(count: Int) -> Data {
        var buf = Array<UInt8>(repeating: 0, count: count)
        let ptr = UnsafeMutableRawPointer(&buf)
        arc4random_buf(ptr, count)
        return Data(buf)
    }
    
    internal func hexValue() -> String {
        return self.map{ String(format:"%02x", $0) }.joined()
    }
}
