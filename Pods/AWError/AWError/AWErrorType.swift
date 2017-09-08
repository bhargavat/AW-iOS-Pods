//
//  AWErrorType.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public typealias AWErrorInfoDict = [String: String]

public protocol AWErrorType: Error {
    var code             : Int { get }
    
    var domain           : String { get }
    var domainPrefix     : String { get }
    var domainSuffix     : String { get }
    var domainIdentifier : String { get }
    
    var errorDescription : String { get }
    var localizableInfo  : String? { get }
    var _userInfo        : AWErrorInfoDict? { get }
    var userInfo         : AWErrorInfoDict? { get }
    var error            : NSError { get }
    
    var stackTrace       : [String] { get }
}

public extension AWErrorType {
    var code: Int { return _code }
    
    var _domain: String { return domain }
    
    var domain: String { return [domainPrefix, domainIdentifier, domainSuffix].filter{ $0.isEmpty == false }.flatMap { $0 }.joined(separator: ".") }
    
    var domainPrefix: String { return "" } // used to be "com.vmware.air-watch"

    var domainSuffix: String { return "" } // used to be "ErrorDomain"

    var domainIdentifier: String {
        let stringSelf = String(reflecting: self)
        let components = stringSelf.replacingOccurrences(of: "\\s?\\([^)]*\\)", with: "", options: .regularExpression, range: stringSelf.startIndex ..< stringSelf.endIndex)
                                                 .characters
                                                 .split(separator: ".")
                                                 .flatMap(String.init)
        guard let indexOfEnum = components.reversed().index(of: "AWError")?.base else {
            return "UNKNOWN.DOMAIN"
        }
        let _domainIdentifier = components.suffix(from: components.index(before:indexOfEnum))
                                          .dropLast()
                                          .joined(separator: ".")
        return _domainIdentifier
    }
    
    var errorDescription: String { return String(describing: self) }
    
    var localizableInfo: String? { return nil }
    
    var _userInfo: AWErrorInfoDict? {
        var userInfoDict: AWErrorInfoDict = [:]
        userInfoDict[NSLocalizedDescriptionKey] = localizableInfo
        return userInfoDict.isEmpty ? nil : userInfoDict
    }
    
    var userInfo: AWErrorInfoDict? { return _userInfo }
    
    var error: NSError {
        return NSError(domain: domain, code: code, userInfo: userInfo)
    }
    
    var stackTrace: [String] {
        return Thread.callStackSymbols
    }
}

