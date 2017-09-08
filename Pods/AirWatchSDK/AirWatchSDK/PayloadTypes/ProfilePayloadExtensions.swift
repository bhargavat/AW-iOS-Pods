//
//  ProfilePayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal protocol PropertyInfo {
    typealias Info = (String, Any, Any.Type)
    func propertiesInfo() -> [Info]
}

extension PropertyInfo
{
    func info(of property: Mirror.Child) -> Info {
        let name = property.label ?? "_"
        let value = property.value
        let type = type(of: value)
        return (name, value, type)
    }
    
    func propertiesInfo() -> [Info] {
        return Mirror(reflecting: self).children.flatMap { info(of: $0) }
    }
}


extension ProfilePayload: PropertyInfo {
    override open var description: String {
        get {
            return self.propertiesInfo().filter { $0.0 != "description" }.flatMap {
                let (name, value, type) = $0
                
                let typeString:String = "\(type)"
                
                let originalValueString  = "\(value)"
                let valueString: String
                // If this is an Array, we need to add right indent to make it more readable
                if typeString.contains("Array") {
                    valueString = originalValueString.components(separatedBy: "\n").joined(separator: "\n\t\t\t")
                } else {
                    valueString = originalValueString
                }
                return "\t\t- " + name + "<" + typeString + ">: " + valueString + "\n"
                }.reduce("\n\t Class Type: \(type(of: self))\n", +)
        }
    }
}

infix operator ??=
func ??= <T>(left: inout T, right: T?) {
    left = right ?? left
}

internal extension Dictionary where Key == String {
    internal func int(for key: Key) -> Int? {
        if let intValue = self[key] as? Int {
            return intValue
        }
        
        guard let stringValue = self[key] as? String else {
            return nil
        }
        
        return Int(stringValue)
    }
    
    internal func double(for key: Key) -> Double? {
        if let doubleValue = self[key] as? Double {
            return doubleValue
        }
        
        guard let stringValue = self[key] as? String else {
            return nil
        }
        
        return Double(stringValue)
    }
    
    internal func bool(for key: Key) -> Bool? {
        if let boolValue = self[key] as? Bool {
            return boolValue
        }
        
        guard let intValue = self.int(for: key) else {
            return nil
        }
        
        return intValue != 0
    }
}
