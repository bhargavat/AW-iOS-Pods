//
//  SecureKeyWrapper.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError


open class SecurityKeyPair {
    open var padding: SecPadding = SecPadding()
    open var publicKey: SecKey? = nil
    open var privateKey: SecKey? = nil

    required public init(publicKey: SecKey?, privateKey: SecKey?) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }

    open var isEmpty: Bool {
        return (publicKey == nil && privateKey == nil)
    }

    open var areBothKeysAvailable: Bool {
        return (self.publicKey != nil && self.privateKey != nil)
    }

    open var blockSize: Int {
        guard self.publicKey != nil else { return 0 }
        return SecKeyGetBlockSize(publicKey!)
    }

    open static func generate(_ keySize: UInt, identifier: String?, persistent: Bool) throws -> SecurityKeyPair {
        SecurityKeyPair.clear(identifier)

        let privateKeyAttr: [String: AnyObject] = [
            String(kSecAttrKeyClass): kSecAttrKeyClassPrivate,
            String(kSecAttrIsPermanent): persistent as AnyObject,
            String(kSecAttrApplicationTag): SecureKeyType.privateKey.applicationTag(identifier) as AnyObject,
        ]

        let publicKeyAttr: [String: AnyObject] = [
            String(kSecAttrKeyClass): kSecAttrKeyClassPublic,
            String(kSecAttrIsPermanent): persistent as AnyObject,
            String(kSecAttrAccessible): kSecAttrAccessibleWhenUnlocked,
            String(kSecAttrApplicationTag): SecureKeyType.publicKey.applicationTag(identifier) as AnyObject
        ]

        let parameters: [String: AnyObject] = [
            String(kSecClass): kSecClassKey,
            String(kSecAttrKeyType): kSecAttrKeyTypeRSA,
            String(kSecAttrKeySizeInBits): keySize as AnyObject,
            String(kSecPrivateKeyAttrs): privateKeyAttr as CFDictionary,
            String(kSecPublicKeyAttrs): publicKeyAttr as CFDictionary
        ]

        var publicKey: SecKey? = nil
        var privateKey: SecKey? = nil
        let result = SecKeyGeneratePair(parameters as CFDictionary, &publicKey, &privateKey)

        if( result != errSecSuccess ) {
            throw AWError.SDK.CryptoKit.SecurityKeyPair.generationFailed(result)
        }

        return SecurityKeyPair(publicKey: publicKey, privateKey: privateKey)
    }

    open static func get(_ identifer: String? = nil) throws -> SecurityKeyPair {
        let pair = SecurityKeyPair(publicKey: nil, privateKey: nil)

        var privateKey: AnyObject? = nil
        let privateKeyQuery = SecureKeyType.privateKey.referenceConversionAttributes(identifer)
        _=withUnsafeMutablePointer(to: &privateKey) {
            SecItemCopyMatching(privateKeyQuery as CFDictionary, UnsafeMutablePointer($0))
        }
        if let pKey = privateKey {
            let key = pKey as! SecKey
            pair.privateKey = key
        }

        var publicKey: AnyObject? = nil
        let publicKeyQuery = SecureKeyType.publicKey.referenceConversionAttributes(identifer)
        _=withUnsafeMutablePointer(to: &publicKey) {
            SecItemCopyMatching(publicKeyQuery as CFDictionary, UnsafeMutablePointer($0))
        }

        if let pKey = publicKey {
            let key = pKey as! SecKey
            pair.publicKey = key
        }

        if pair.isEmpty {
            throw AWError.SDK.CryptoKit.SecurityKeyPair.unavailableForGivenIdentifier
        }

        return pair
    }

    open static func clear(_ identifier: String? = nil) {
        let publicKeyAttributes = SecureKeyType.publicKey.attributes(identifier)
        let publicKeyClearingStatus = SecItemDelete(publicKeyAttributes as CFDictionary)
        if publicKeyClearingStatus != noErr {
            log(error:"Clearing Public Key Failed with status: \(publicKeyClearingStatus)")
        }

        let privateKeyAttributes = SecureKeyType.privateKey.attributes(identifier)
        let privateKeyClearingStatus = SecItemDelete(privateKeyAttributes as CFDictionary)
        if privateKeyClearingStatus != noErr {
            log(error:"Clearing Private Key Failed with status: \(privateKeyClearingStatus)")
        }
    }

}
