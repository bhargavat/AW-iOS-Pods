//
//  EncryptedFileHeader.swift
//  AWCryptoKit
//
//  Created by "Liu, Troy" on 12/8/16.
//  Copyright © 2016 VMware, Inc. All rights reserved.
//

import Foundation
import AWError

let magicBytes : [UInt8] = [0x79, 0x51, 0x07, 0x6D, 0xAF, 0x52, 0xBB, 0x2D, 0xA0, 0x2E, 0x4D, 0x0C, 0xA0, 0x8E, 0xC0, 0x04]

fileprivate extension Data {
    /** Purpose of this function:
     *  Usually, the data will give us an Array of UInt8 elements, but this is probably not what we want.
     *  For example, a lot of properties in struct EncryptedFileHeader is of type UInt16, UInt32 and UInt64,
     *  which means we need further conversion to get the target value. 
     *  But with following extension method, things can get a whole lot easier. For example, keySizeData is
     *  of Data type with bytes [0x01, 0x02]
     *  Now, our target propery keySize is of type UInt16, how can we get that from the keySizeData?
     *  You just need to do
     *
     *  let keySize: UInt16 = keySizeData.toUnsignedInteger()
     *
     *  And keySize will be 513, which is what we want.
     *  Another example, fileSizeData is of Data type with bytes [0x01, 0x02, 0x03, 0x04], and we need to
     *  convert it to UInt64. Here is what we can do with this extension function:
     *
     *  let fileSize: UInt64 = fileSizeData.toUnsignedInteger()
     *
     *  And fileSize will be 67305985, which, again, is what we want.
     *  
     *  Attention, there is something you need know when you use this function, which is that you need to
     *  provide the right target type, or the result could be terriblly wrong. For instance, in the
     *  previous example, if we declare fileSize as UInt16 instead of UInt64 like this:
     *
     *  (WRONG!)
     *  let fileSize: UInt16 = fileSizeData.toUnsignedInteger()
     *
     *  Then the fileSize will be 513 instead of 67305985. Please be ware.
     */
    func toUnsignedInteger<A>() -> A where A: UnsignedInteger {
        return self.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> A in
            return bytes.withMemoryRebound(to: A.self, capacity: 1) { $0.pointee }
        }
    }
}

public extension UnsignedInteger {
    // Convert UnsignedInteger(UInt64, UInt32, UInt16, UInt8) to UInt8 Array a.k.a bytes 
    // Example:
    // let test: UInt64 = 67305985
    // let bytes = test.toUInt8Array()
    // The bytes will be a UInt8 Array of [1, 2, 3, 4, 0, 0, 0, 0]
    func toUInt8Array() -> [UInt8] {
        var mutableSelf = self
        let bytePointer = withUnsafePointer(to: &mutableSelf) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: self)) {
                UnsafeBufferPointer(start: $0, count: MemoryLayout.size(ofValue: self))
            }
        }
        let bytes = Array(bytePointer)
        return bytes
    }
}

fileprivate protocol DataToUnsignedIntegerConvertible: UnsignedInteger {
    init(with data: Data, from index: inout Int)
}

fileprivate extension DataToUnsignedIntegerConvertible {
    init(with data: Data, from index: inout Int) {
        let selfSize = MemoryLayout<Self>.size
        let selfData = data.subdata(in: index ..< index + selfSize)
        self = selfData.toUnsignedInteger()
        index += selfSize
    }
}

extension UInt8 : DataToUnsignedIntegerConvertible { }
extension UInt16: DataToUnsignedIntegerConvertible { }
extension UInt32: DataToUnsignedIntegerConvertible { }
extension UInt64: DataToUnsignedIntegerConvertible { }


struct EncryptedFileHeaderInfo {
    let headerSignature: Data
    static let headerSignatureCount = 16
    
    let headerSize: UInt16
}

extension EncryptedFileHeaderInfo {
    init?(fromData inputData: Data) {
        var startIndex = 0
        
        // The Header Signature must be 0x7951076daf52bb2da02e4d0ca08ec004
        let headerSignatureData = inputData.subdata(in: startIndex ..< startIndex + EncryptedFileHeaderInfo.headerSignatureCount)
        if headerSignatureData != Data(bytes: magicBytes) {
            return nil
        }
        self.headerSignature = headerSignatureData
        startIndex += EncryptedFileHeaderInfo.headerSignatureCount
        
        // Extract header size
        self.headerSize = .init(with: inputData, from: &startIndex)
    }
}

struct EncryptedFileHeader {
    static let minimumHeaderSize = 24
    
    let version: UInt16
    
    let fileSize: UInt64
    
    let mimeTypeSize: UInt16
    
    let algorithm: UInt16
    
    let keySize: UInt16
    
    let paddingMethod: UInt16
    
    let hashAlgorithm: UInt16
    
    let hashSize: UInt16
    
    let ivSize: UInt16
    
    let maskSize: UInt32
    
    let mimeType: String?
    var optionMask: Data
    let keyHash: Data
    let ivData: Data
}

extension EncryptedFileHeader {
    init?(fromData inputData: Data) {
        var startIndex = 0
        
        // Extract version
        self.version = .init(with: inputData, from: &startIndex)
        
        // Extract file size
        self.fileSize = .init(with: inputData, from: &startIndex)
        
        // Extract mime type size
        self.mimeTypeSize = .init(with: inputData, from: &startIndex)
        
        // Extract algorithm
        self.algorithm = .init(with: inputData, from: &startIndex)
        
        // Extract key size
        self.keySize = .init(with: inputData, from: &startIndex)
        
        // Extract padding type
        self.paddingMethod = .init(with: inputData, from: &startIndex)
        
        // Extract hash algorithm
        self.hashAlgorithm = .init(with: inputData, from: &startIndex)
        
        // Extract hash size
        self.hashSize = .init(with: inputData, from: &startIndex)
        
        // Extract iv size
        self.ivSize = .init(with: inputData, from: &startIndex)
        
        // Hard code mask size to be 4
        self.maskSize = 4
        
        // Extract option mask data
        self.optionMask = inputData.subdata(in: startIndex ..< startIndex + Int(self.maskSize))
        startIndex += Int(self.maskSize)
        
        // Extract mime type data, and convert it to string
        let mimeTypeData = inputData.subdata(in: startIndex ..< startIndex + Int(self.mimeTypeSize))
        self.mimeType = String(data: mimeTypeData, encoding: .utf8)
        startIndex += Int(self.mimeTypeSize)
        
        // Extrack key hash
        self.keyHash = inputData.subdata(in: startIndex ..< startIndex + Int(self.hashSize))
        startIndex += Int(self.hashSize)
        
        // Extract iv
        self.ivData = inputData.subdata(in: startIndex ..< startIndex + Int(self.ivSize))
        startIndex += Int(self.ivSize)
        
        // xor the optionmask with the first 4 bytes of the keyhash
        self.retrieveOptionFlags()
    }
    
    mutating func retrieveOptionFlags() -> () {
        var maskBytes: [UInt8] = Array(self.optionMask)
        let hashBytes: [UInt8] = Array(self.keyHash)
        let count = min(maskBytes.count, hashBytes.count)
        (0 ..< count).forEach { idx in
            maskBytes[idx] ^= hashBytes[idx]
        }
        self.optionMask = Data(bytes: maskBytes)
    }
}
