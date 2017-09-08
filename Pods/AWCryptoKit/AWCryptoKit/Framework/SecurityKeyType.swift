//
//  SecureKeyType.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public enum SecureKeyType: Int {
    case publicKey
    case privateKey

    internal var tag: String {
        switch self {
        case .privateKey:
            return "private.tag"

        case .publicKey:
            return "public.tag"
        }
    }

    internal func applicationTag(_ identifer: String?) -> String {
        if let id = identifer {
            return (id + self.tag)
        }

        return self.tag
    }

    internal func identifierData(_ identifer: String?) -> Data? {
        if let id = identifer {
            return (id + self.tag).data(using: .utf8)
        }

        return self.tag.data(using: .utf8)
    }


    public func attributes(_ identifer: String?) -> [String: AnyObject] {
        var map: [String: AnyObject] =  [
            String(kSecClass): kSecClassKey,
            String(kSecAttrKeyType): kSecAttrKeyTypeRSA
        ]

        if let data = self.identifierData(identifer) {
            map[String(kSecAttrApplicationTag)] = data as AnyObject?
        }

        switch self {
        case .privateKey:
            map[String(kSecAttrKeyClass)] = kSecAttrKeyClassPrivate
            break

        case .publicKey:
            map[String(kSecAttrKeyClass)] = kSecAttrKeyClassPublic
            map[String(kSecAttrAccessible)] = kSecAttrAccessibleWhenUnlocked
            break
        }

        return map
    }

    public func dataConversionAttributes(_ identifer: String?) -> [String: AnyObject] {
        var attributes = self.attributes(identifer)
        attributes[String(kSecReturnData)] = true as AnyObject?
        return attributes
    }

    public func referenceConversionAttributes(_ identifer: String?) -> [String: AnyObject] {
        var attributes = self.attributes(identifer)
        attributes[String(kSecReturnRef)] = true as AnyObject?
        return attributes
    }
}
