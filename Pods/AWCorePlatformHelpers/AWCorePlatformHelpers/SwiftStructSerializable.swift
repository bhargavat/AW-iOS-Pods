//
//  SwiftStructSerializable.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError


/**
    Swift doesn't allow cast Any to RawPresentible thus it's impossible to access raw value
    for enum types directly. So all enum types included in SwiftStructSerializable objects
    should conform to this protocol.
 */
public protocol SwiftEnumSerializable {
    func data() throws -> Data
}


public extension SwiftEnumSerializable {
    public func dataFromInteger<T: Integer>(_ integer: T) -> Data {
        var intVal = integer
        
        return withUnsafePointer(to: &intVal, { (ptr: UnsafePointer<T> ) in
            let ret = Data(bytes: ptr, count: MemoryLayout<T>.size)
            return ret
        })

    }
}

/// Does not allow for Optional data members within the Struct
/// the data() method will throw an error if an Optional property is detected while processing the Struct
public protocol SwiftStructSerializable {
    func data() throws -> Data
}

/// Does not allow for Optional data members within the Struct
public extension SwiftStructSerializable {
    
    fileprivate func build(_ val: Any) throws -> Data {
        var bytesData = Data()
        let mirror = Mirror(reflecting: val)
        
        // Make sure we're analyzing a struct
        guard mirror.displayStyle == .struct else {
            throw AWError.SDK.CorePlatformHelpers.SwiftStructSerialization.structRequired
        }
        
        for case let (label?, anyValue) in mirror.children {
            guard label.contains("pointer") == false else { continue }
            
            let ReflectOfValue = Mirror(reflecting: anyValue)
            if let typeOfValue = ReflectOfValue.displayStyle {
                
                let reflectedData = try processReflectedValue(type: typeOfValue, value: anyValue, label: label)
                bytesData.append(reflectedData)
                
            } else {
                /// primitive types
                let primitiveData = try processPrimitive(value: anyValue, label: label)
                bytesData.append(primitiveData)
            }
        }

        return bytesData
    }
    
    private func processReflectedValue(type: Mirror.DisplayStyle, value: Any, label: String?) throws -> Data {
        
        switch type{
        case .struct:
            return try processStruct(value:value)
            
        case .enum:
            guard let enumVal = value as? SwiftEnumSerializable else {
                throw AWError.SDK.CorePlatformHelpers.SwiftStructSerialization.unsupportedSerializationType(label: label)
            }
            return try enumVal.data()
            
        case .class:
            guard let classValue = value as? Data else {
                throw AWError.SDK.CorePlatformHelpers.SwiftStructSerialization.unsupportedSerializationType(label: label)
            }
            return classValue
            
        case .collection:
            guard let arrayValue = value as? [UInt8] else {
                throw AWError.SDK.CorePlatformHelpers.SwiftStructSerialization.unsupportedSerializationType(label: label)
            }
            return Data(bytes: arrayValue)
            
        default:
            ///TODO: Support other serializable value types (dictionary, array)
            throw AWError.SDK.CorePlatformHelpers.SwiftStructSerialization.unsupportedSerializationType(label: label)
        }
    }
    
    private func processStruct(value: Any) throws -> Data {
        if let dataValue = value as? Data {
            return dataValue
        }
        return try build(value)
    }
    
    private func processPrimitive(value: Any, label: String?) throws -> Data {
        
        if let intValue = tryToProcessAs(intValue: value) {
            return intValue
        }
        if let floatValue = tryToProcessAs(floatValue: value) {
            return floatValue
        }
        if let stringValue = value as? String, let utf8Data = (stringValue).data(using: String.Encoding.utf8) {
            return utf8Data
        }
        
        throw AWError.SDK.CorePlatformHelpers.SwiftStructSerialization.unsupportedSerializationType(label: label)
        
    }
    
    private func tryToProcessAs(intValue: Any) -> Data? {
        var inoutVal = intValue
        
        switch intValue {
        case is Int: fallthrough
        case is UInt:
            return Data(bytes: &inoutVal, count: MemoryLayout<Int>.size)
            
        case is Int8: fallthrough
        case is UInt8:
            return Data(bytes: &inoutVal, count: MemoryLayout<Int8>.size)
            
        case is Int16: fallthrough
        case is UInt16:
            return Data(bytes: &inoutVal, count: MemoryLayout<Int16>.size)
            
        case is Int32: fallthrough
        case is UInt32:
            return Data(bytes: &inoutVal, count: MemoryLayout<Int32>.size)
            
        case is Int64: fallthrough
        case is UInt64:
            return Data(bytes: &inoutVal, count: MemoryLayout<Int64>.size)
            
        default:
            return nil
        }
        
    }
    
    private func tryToProcessAs(floatValue: Any) -> Data? {
        var inoutVal = floatValue
        
        switch floatValue {
        case is Float: fallthrough
        case is Float32:
            return Data(bytes: &inoutVal, count: MemoryLayout<Float>.size)
            
        case is Float64: fallthrough
        case is Double:
            return Data(bytes: &inoutVal, count: MemoryLayout<Float64>.size)
            
        default:
            return nil
        }
        
    }

    public func data() throws -> Data {
        return try build(self)
    }
}
