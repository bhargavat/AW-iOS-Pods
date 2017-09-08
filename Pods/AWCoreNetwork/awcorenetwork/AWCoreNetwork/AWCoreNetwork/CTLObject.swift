//
//  CTLObject.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
 The protocol to build data object from NSData.
 */
public protocol CTLDataObjectProtocol {
    static func objectWithData(_ data: Data?, additionalProperties: Dictionary<String, AnyObject>?) throws -> Self
}


open class CTLObject: NSObject {
    open var properties: Dictionary<String, AnyObject>? = nil
}


public final class CTLJSONObject: CTLObject, CTLDataObjectProtocol {

    fileprivate var json: AnyObject?
    public var JSON: AnyObject? {
        return json
    }

    public static func objectWithData(_ data: Data?, additionalProperties: Dictionary<String, AnyObject>?)
        throws -> CTLJSONObject {
            do {
                let obj = try CTLJSONObject(data: data)
                obj.properties = additionalProperties
                return obj
            } catch let err {
                throw err
            }
    }

    init(data: Data?) throws {
        super.init()
        guard let rawData = data, rawData.count > 0 else {
            self.json = nil
            return
        }

        self.json = try self.parse(rawData)
    }


    fileprivate func parse(_ rawData: Data) throws -> AnyObject {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: rawData, options: JSONSerialization.ReadingOptions.mutableContainers)
            return jsonObject as AnyObject
        } catch let err as NSError {
            log(error: "Failed to parse data into JSON object")
            throw err
        }
    }
}


public final class CTLPlistObject: CTLObject, CTLDataObjectProtocol {

    fileprivate var plist: AnyObject?
    public var PLIST: AnyObject? {
        return plist
    }
 
    public static func objectWithData(_ data: Data?, additionalProperties: Dictionary<String, AnyObject>?)
        throws -> CTLPlistObject {
            let obj = try CTLPlistObject(data: data)
            obj.properties = additionalProperties
            return obj
    }

    init(data: Data?) throws {
        super.init()
        guard let rawData = data, rawData.count > 0 else {
            self.plist = nil
            return
        }

        self.plist = try self.parse(rawData)
    }


    fileprivate func parse(_ rawData: Data) throws -> AnyObject {
        do {
            let plistObject = try PropertyListSerialization.propertyList(from: rawData,
                                                                         options: PropertyListSerialization.MutabilityOptions(),
                                                                         format: nil)
            return plistObject as AnyObject
        } catch let err as NSError {
            log(error: "Failed to parse data into PLIST object")
            throw err
        }
    }
}
