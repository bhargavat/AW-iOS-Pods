//
//  NSData+BytewiseXOR.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 ^ operator override for NSData, to provide a bytewise XOR of the represented data
 Both operands must be of length > 0
 Both operands must be of equal length to eachother
 Result will be NSData? of the XOR'd bytes of the 2 operands
 */
func ^(left: Data, right: Data) -> Data? {
    assert(right.count > 0, "data of greater than 0 length only")
    assert(left.count > 0, "data of greater than 0 length only")
    
    guard right.count == left.count else {
        return nil
    }
    
    var leftPtr = [UInt8](repeating: 0x00, count: left.count)
    var rightPtr = [UInt8](repeating: 0x00, count: right.count)
    
    left.copyBytes(to: &leftPtr, count: left.count)
    right.copyBytes(to: &rightPtr, count: right.count)
    
    var i = 0
    while i < left.count {
        leftPtr[i] = leftPtr[i] ^ rightPtr[i]
        i += 1
    }
    
    let result: Data = Data(bytes: &leftPtr, count: left.count)
    
    return result
}
