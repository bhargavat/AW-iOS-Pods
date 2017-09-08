//
//  KeychainDataStore.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


public protocol AbstractKeychainDataStore: AbstractKeyValueStore {}

public extension AbstractKeychainDataStore {

    internal func genericQuery(_ groupname: String, service: String) -> [ String : AnyObject ] {
        return [ String(kSecClass) : kSecClassGenericPassword,
                 String(kSecAttrAccount) : groupname as AnyObject,
                 String(kSecAttrService) : service as AnyObject ]
    }

    public func get<DR: DataRepresentable>(_ group: String, key: String) -> DR? {
        guard group.characters.count != 0 else { return nil }
        guard key.characters.count != 0 else { return nil }
        var query = self.genericQuery(group, service: key)
        query[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        query[String(kSecReturnData)] = true as AnyObject
        var data: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &data )
        if result != noErr && result != errSecItemNotFound { AWLogDebug("AWKeychain read Error Code : \(result)") }
//        print("___________________________________________________________________________")
//        print("Account: \(account) Service:\(key) Retrieved Data: \(data)")
//        print("___________________________________________________________________________")
        let keychainReturnedData = data as? Data
        guard let decryptor = self.cryptor
            else { return DR.fromData(keychainReturnedData) }

        return DR.fromData(decryptor.decryptObject(keychainReturnedData))
    }


    internal func delete(_ itemQuery: [ String : AnyObject ]) -> Bool {
        let query = itemQuery
        let result = SecItemDelete(query as CFDictionary)
        let operationFailed = (result != noErr && result != errSecItemNotFound)
        if operationFailed {
            AWLogDebug("AWKeychain Delete Error Code : \(result)")
        }
        return !operationFailed
    }

    internal func update(_ itemQuery: [ String : AnyObject ], data: Data) -> Bool {
        var updateArttributes = [String: AnyObject] ()
        updateArttributes[String(kSecValueData)] = data as AnyObject
        updateArttributes[String(kSecAttrModificationDate)] = Date() as AnyObject
        updateArttributes[String(kSecAttrAccessible)] = String(kSecAttrAccessibleAfterFirstUnlock) as AnyObject
        let result = SecItemUpdate(itemQuery as CFDictionary, updateArttributes as CFDictionary)
        if result != noErr { AWLogError("AWKeychain Udpate Error Code:\(result)") }
        return (result == noErr)
    }

    internal func add(_ itemQuery: [ String : AnyObject ], data: Data) -> Bool {
        var query = itemQuery
        query[String(kSecValueData)] = data as AnyObject
        query[String(kSecAttrCreationDate)] = Date() as AnyObject
        query[String(kSecAttrAccessible)] = String(kSecAttrAccessibleAfterFirstUnlock) as AnyObject
        let result = SecItemAdd(query as CFDictionary, nil)
        if result != noErr { AWLogError("AWKeychain add Error Code:\(result)") }
        return (result == noErr)
    }
    @discardableResult mutating public func set<DR: DataRepresentable>(_ group: String, key: String, value: DR?) -> Bool {
        guard key.characters.count != 0 else { return false }
        guard group.characters.count != 0 else { return false }

        let itemQuery = self.genericQuery(group, service: key)
        var dataValue: Data? = nil

        if let encryptor = self.cryptor,
            let newValue = value {
            dataValue = encryptor.encryptObject(newValue)
        } else {
            dataValue = value?.toData() as Data?
        }
        
        guard let newValue = dataValue else {
            return self.delete(itemQuery)
        }
    
        var rawItemQuery = itemQuery
        rawItemQuery[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        rawItemQuery[String(kSecReturnData)] = true as AnyObject
        var rawData: AnyObject?
        let result = SecItemCopyMatching(rawItemQuery as CFDictionary, &rawData)
        
        guard result == noErr else {
            return self.add(itemQuery, data: newValue)
        }
        
        return self.update(itemQuery, data: newValue)
    }

    func getlastUpdatedTimestamp(_ group: String, key: String) -> TimeInterval? {
        var itemQuery = self.genericQuery(group, service: key)
        itemQuery[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        itemQuery[String(kSecReturnAttributes)] = true as AnyObject
        var result: AnyObject? = nil
        if SecItemCopyMatching(itemQuery as CFDictionary, &result) != noErr { return nil }
        if let resultDictionary = result as? [String: AnyObject],
            let modificateDate = resultDictionary[String(kSecAttrModificationDate)] as? Date {
            return modificateDate.timeIntervalSince1970
        }
        return  nil
    }

    mutating func clearGroup(_ groupName: String) -> Bool {
        let query: [String : AnyObject ] = [
            String( kSecClass) : kSecClassGenericPassword,
            String( kSecAttrAccount ) : groupName as AnyObject
        ]

        let result: OSStatus = SecItemDelete(query as CFDictionary)
        if result != noErr { AWLogError("AWKeychain Remove all error code: \(result)") }
        return result == noErr
    }
}
