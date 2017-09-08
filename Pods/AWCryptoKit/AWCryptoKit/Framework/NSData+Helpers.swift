//
//  NSData+Helpers.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal extension Data {
  
    internal var hexString: String {
        var byteArray = [UInt8](repeating: 0x0, count: self.count)
        self.copyBytes(to: &byteArray, count: self.count)
        return byteArray
            .map { String(format: "%02x", $0) }
            .reduce( "", + )
    }

}

