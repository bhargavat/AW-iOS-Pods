//
//  AuthenticatonInfo.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWStorage

extension CoderKeys {
    class AuthenticatonInfo {
        static let authorizationGroup = "AWHMACAuthenticationGroup"
        static let hmacToken = "AWHMACKey"
    }
}
open class AuthenticatonInfo: NSObject, NSCoding {
    open var authorizationGroup: String?
    open var hmacToken: String?

    @objc required convenience public init(coder decoder: NSCoder) {
        self.init()
        self.authorizationGroup = decoder.decodeObject(forKey: CoderKeys.AuthenticatonInfo.authorizationGroup) as? String
        self.hmacToken = decoder.decodeObject(forKey: CoderKeys.AuthenticatonInfo.hmacToken) as? String
    }

    @objc required convenience public init(authorizationGroup: String?, hmacToken: String?) {
        self.init()
        self.authorizationGroup = authorizationGroup
        self.hmacToken = hmacToken
    }

    @objc open func encode(with coder: NSCoder) {

        if let authorizationGroup = authorizationGroup {
            coder.encode(authorizationGroup, forKey: CoderKeys.AuthenticatonInfo.authorizationGroup)
        }

        if let hmacToken = hmacToken {
            coder.encode(hmacToken, forKey: CoderKeys.AuthenticatonInfo.hmacToken)
        }
    }
}


extension AuthenticatonInfo: DataRepresentable {

    public func toData() -> Data? {
        var dictionary: [String: AnyObject] = [:]

        if let hmactoken = self.hmacToken {
            dictionary[CoderKeys.AuthenticatonInfo.hmacToken] =  hmactoken.data(using: String.Encoding.utf8) as AnyObject?
        }

        if let authenticationGroup = self.authorizationGroup {
            dictionary[CoderKeys.AuthenticatonInfo.authorizationGroup] =  authenticationGroup as AnyObject?
        }
        return (dictionary as NSDictionary).toData()
    }

    public static func fromData(_ data: Data?) -> Self? {
        if let dictionary = NSDictionary.fromData(data),
            let map  = dictionary as? [String: AnyObject] {


            var hmacToken: String? = nil
            if let hmacTokenData = map[CoderKeys.AuthenticatonInfo.hmacToken] as? Data {
                hmacToken = String(data: hmacTokenData, encoding: String.Encoding.utf8)
            }
            let authorizationGroup = map[CoderKeys.AuthenticatonInfo.authorizationGroup] as? String
            let authenticationInfo = self.init(authorizationGroup: authorizationGroup, hmacToken: hmacToken)
            return authenticationInfo
        }

        return nil
    }

}

extension AuthenticatonInfo {

    open override func isEqual(_ object: Any?) -> Bool {
        if self === object as AnyObject? { return true }

        if let other = object as? AuthenticatonInfo {
            return (self.authorizationGroup == other.authorizationGroup && self.hmacToken == other.hmacToken)
        }
        return false
    }

}
