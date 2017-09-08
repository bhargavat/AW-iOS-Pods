//
//  AWDigest.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public enum Digest {
    case md5
    case sha1
    case sha256
    case sha512

    public var digestLength: Int32 {

        switch self {
        case .md5:
            return CC_MD5_DIGEST_LENGTH

        case .sha1:
            return CC_SHA1_DIGEST_LENGTH

        case .sha256:
            return CC_SHA256_DIGEST_LENGTH

        case .sha512:
            return CC_SHA512_DIGEST_LENGTH
        }
    }

    public func digest(_ data: Data) -> Data? {
        var digestData = [UInt8](repeating: 0x00, count: Int(digestLength))

        var result: UnsafeMutablePointer<UInt8>? = nil
        switch self {
        case .md5:
            result = data.withUnsafeBytes({ (dataBytes) -> UnsafeMutablePointer<UInt8> in
                return CC_MD5(dataBytes, UInt32(data.count), &digestData)
            })

        case .sha1:
            result = data.withUnsafeBytes({ (dataBytes) -> UnsafeMutablePointer<UInt8> in
                return CC_SHA1(dataBytes, UInt32(data.count), &digestData)
            })

        case .sha256:
            result = data.withUnsafeBytes({ (dataBytes) -> UnsafeMutablePointer<UInt8> in
                return CC_SHA256(dataBytes, UInt32(data.count), &digestData)
            })

        case .sha512:
            result = data.withUnsafeBytes({ (dataBytes) -> UnsafeMutablePointer<UInt8> in
                return CC_SHA512(dataBytes, UInt32(data.count), &digestData)
            })
        }
        
        return Data(bytes: UnsafePointer<UInt8>(result!), count: Int(digestLength))
    }
}


extension NSData {

    @objc(aw_md5)
    public var md5: NSData? {
        
        if let digest = Digest.md5.digest(self as Data) {
            return digest as NSData
        }
        return nil
    }

    @objc(aw_sha1)
    public var sha1: NSData? {
        if let digest = Digest.sha1.digest(self as Data){
            return digest as NSData
        }
        return nil
    }

    @objc(aw_sha256)
    public var sha256: NSData? {
        if let digest = Digest.sha256.digest(self as Data){
            return digest as NSData
        }
        return nil
    }

    @objc(aw_sha512)
    public var sha512: NSData? {
        if let digest = Digest.sha512.digest(self as Data){
            return digest as NSData
        }
        return nil
    }
}

extension Data {

    public var md5: Data? {
        return Digest.md5.digest(self)
    }
    
    public var sha1: Data? {
        return Digest.sha1.digest(self)
    }
    
    public var sha256: Data? {
        return Digest.sha256.digest(self)
    }
    
    public var sha512: Data? {
        return Digest.sha512.digest(self)
    }
}
