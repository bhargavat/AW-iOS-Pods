//
//  Types.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public protocol StoreCryptor {
    func encryptObject<DR: DataRepresentable>(_ object: DR?) -> Data?
    func decryptObject<DR: DataRepresentable>(_ data: Data?) -> DR?
}

public protocol DataRepresentable {
    func toData() -> Data?
    static func fromData(_ data: Data?) -> Self?
}

public extension DataRepresentable where Self: NSCoding {
    func toData() -> Data? {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }

    static func fromData(_ data: Data?) -> Self? {
        guard let codedData = data else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(with: codedData) as? Self
    }
}

extension Data: DataRepresentable {
    public func toData() -> Data? { return self }

    public static func fromData(_ data: Data?) -> Data? {
        guard data != nil else { return nil }
        return self.init(data!)
    }
}


extension NSDictionary: DataRepresentable {

    public func toData() -> Data? {
        return try? PropertyListSerialization.data(fromPropertyList: self,
                                                                     format: .xml,
                                                                     options: PropertyListSerialization.WriteOptions(0))
    }

    public static func fromData(_ data: Data?) -> Self? {
        guard let plistData = data else { return nil }

        if let plist =  try? PropertyListSerialization.propertyList(from: plistData,
                                                                              options: PropertyListSerialization.ReadOptions(rawValue: 0),
                                                                              format: nil) {
            let allValues = (plist as AnyObject).allValues
            if let allKeys = (plist as AnyObject).allKeys as? [NSCopying] {
                return self.init(objects: allValues!, forKeys: allKeys)
            }
        }
        return nil
    }
}

extension Int: DataRepresentable {
    public func toData() -> Data? {
        return String(format: "%ld", self).data(using: String.Encoding.utf8)
    }

    public static func fromData(_ data: Data?) -> Int? {
        guard let integerData = data else { return nil }
        if let string = String(data: integerData, encoding: String.Encoding.utf8) {
            return Int(string)
        }
        return nil
    }
}

extension UInt: DataRepresentable {
    public func toData() -> Data? {
        return String(format: "%lu", self).data(using: String.Encoding.utf8)
    }

    public static func fromData(_ data: Data?) -> UInt? {
        guard let integerData = data else { return nil }
        if let string = String(data: integerData, encoding: String.Encoding.utf8) {
            return UInt(string)
        }
        return nil
    }
}

extension Double: DataRepresentable {
    public func toData() -> Data? {
        return String(format: "%f", self).data(using: String.Encoding.utf8)
    }

    public static func fromData(_ data: Data?) -> Double? {
        guard let doubleData = data else { return nil }
        if let string = String(data: doubleData, encoding: String.Encoding.utf8) {
            return Double(string)
        }
        return nil
    }
}

extension Bool: DataRepresentable {
    public func toData() -> Data? {
        if self {
            return "1".data(using: String.Encoding.utf8)
        }
        return nil
    }

    public static func fromData(_ data: Data?) -> Bool? {
        if let boolData = data {
            return (String(data:boolData, encoding: String.Encoding.utf8) == "1")
        }
        return nil
    }
}

extension String: DataRepresentable {
    public func toData() -> Data? {
        return self.data(using: String.Encoding.utf8)
    }

    public static func fromData(_ data: Data?) -> String? {
        guard let stringData = data else { return nil }
        return String(data: stringData, encoding: String.Encoding.utf8)
    }
}

extension Date: DataRepresentable {
    public func toData() -> Data? {
        return self.timeIntervalSince1970.toData()
    }

    public static func fromData(_ data: Data?) -> Date? {
        if let interval = Double.fromData(data) {
            return self.init(timeIntervalSince1970: interval)
        }
        return nil
    }
}
