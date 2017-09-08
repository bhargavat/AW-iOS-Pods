//
//  CipherAlgorithm.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public enum CipherAlgorithm {

    case aes128, aes192, aes256, des, des3

    public var algorithm: CCAlgorithm {
        switch self {
        case .aes128:
            fallthrough
        case .aes192:
            fallthrough
        case .aes256:
            return UInt32(kCCAlgorithmAES128)

        case .des:
            return UInt32(kCCAlgorithmDES)

        case .des3:
            return UInt32(kCCAlgorithm3DES)
        }
    }

    public var keysize: Int {
        switch self {
        case .aes128:
            return kCCKeySizeAES128

        case .aes192:
            return kCCKeySizeAES192

        case .aes256:
            return kCCKeySizeAES256

        case .des:
            return kCCKeySizeDES

        case .des3:
            return kCCKeySize3DES
        }
    }

    public var blockSize: Int {
        switch self {
        case .aes128:
            fallthrough
        case .aes192:
            fallthrough
        case .aes256:
            return kCCBlockSizeAES128

        case .des:
            return kCCBlockSizeDES

        case .des3:
            return kCCBlockSize3DES
        }
    }
}
