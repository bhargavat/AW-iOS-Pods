//
//  BufferedDigest.swift
//  AirWatchCrypto
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public final class BufferedDigest {
    
    fileprivate var md5_context = CC_MD5_CTX()
    fileprivate var sha1_context = CC_SHA1_CTX()
    fileprivate var sha256_context = CC_SHA256_CTX()
    fileprivate var sha512_context = CC_SHA512_CTX()
    
    
    fileprivate let OperationStatusSuccess: Int32 = 1
    fileprivate(set) public var algorithm: Digest
    public var context: UnsafeMutableRawPointer?

    public init(algorithm: Digest) {
        self.algorithm = algorithm
        self.context = nil
        switch algorithm {
        case .md5:
            CC_MD5_Init(&md5_context)
            
        case .sha1:
            CC_SHA1_Init(&sha1_context)
            
        case .sha256:
            CC_SHA256_Init(&sha256_context)
            
        case .sha512:
            CC_SHA512_Init(&sha512_context)
        }

    }

    public func update(_ data: Data) -> Bool {
        var updateStatus: Int32 = 0
        var bytes = [UInt8](repeating: 0x00, count: data.count)
        data.copyBytes(to: &bytes, count: data.count)
        switch algorithm {
        case .md5:
            updateStatus = CC_MD5_Update(&md5_context, bytes, UInt32(data.count))

        case .sha1:
            updateStatus = CC_SHA1_Update(&sha1_context, bytes, UInt32(data.count))

        case .sha256:
            updateStatus = CC_SHA256_Update(&sha256_context, bytes, UInt32(data.count))

        case .sha512:
            updateStatus = CC_SHA512_Update(&sha512_context, bytes, UInt32(data.count))
        }

        return (updateStatus == OperationStatusSuccess)
    }

    public func finalize() -> Data? {
        var digest = [UInt8](repeating: 0, count: Int(algorithm.digestLength))
        var finalizedStatus: Int32 = 0

        switch algorithm {
        case .md5:
            finalizedStatus = CC_MD5_Final(&digest, &md5_context)

        case .sha1:
            finalizedStatus = CC_SHA1_Final(&digest, &sha1_context)

        case .sha256:
            finalizedStatus = CC_SHA256_Final(&digest, &sha256_context)

        case .sha512:
            finalizedStatus = CC_SHA512_Final(&digest, &sha512_context)
        }

        guard finalizedStatus == OperationStatusSuccess else {
            return nil
        }
        
        return Data(bytes: digest)
    }
}
