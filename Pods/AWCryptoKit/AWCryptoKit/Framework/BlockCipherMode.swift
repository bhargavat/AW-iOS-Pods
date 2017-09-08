//
//  CipherMode.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public enum BlockCipherMode {

    case ecb, cbc

    public var options: CCOptions {
        switch self {
        case .ecb:
            return UInt32(kCCOptionECBMode) | UInt32(kCCOptionPKCS7Padding)

        case .cbc:
            return UInt32(kCCOptionPKCS7Padding)
        }
    }
}
