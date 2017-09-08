//
//  SettingsImpl.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWError
import Foundation


/// This file is copied from Garnet

/// Settings class that can access KeychainSettings or UserDefaultSettings
/// invisbily to the caller
open class SettingsImpl: SettingsStore {
    // MARK: - Public
    /// Singleton Accessor
    static let sharedInstance: SettingsStore = SettingsImpl()

    // MARK: Protocol Methods
    @discardableResult
    open func clearAll() -> StorageResult {
        clearAllUnsecureKeys()

        return clearSecureKeys()
    }

    @discardableResult
    open func clearAllUnsecureKeys() -> StorageResult {
        self.userDefaultsStore.clearAllKnownUnsecureItems()
        return StorageResult.success(nil)
    }

    @discardableResult
    open func clearSecureKeys() -> StorageResult {
        let keychainResult = self.keychainStore.clearNonsharedKnownSecureItems()

        switch (keychainResult) {
        case .failure(let error):
            return StorageResult.failure(error)
        default:
            return StorageResult.success(nil)
        }
    }

    /**
     Clear safe to overwrite shared keychain data from the keychain

     The current exception from total clear of shared secure items, is shared Device UDID

     - Returns: the result from the keycahin modification
     */
    open func clearSafeSharedKeys() -> StorageResult {
        let finalResult: StorageResult = safelyClearSharedKeychain()

        return finalResult
    }

    open func wipeDevice() -> StorageResult {
        var finalResult: StorageResult = clearAllUnsecureKeys()
        var tempResult = clearSecureKeys()
        if (finalResult.isSuccess == true) {
            finalResult = tempResult
        }
        tempResult = clearSharedKeychain()
        if (finalResult.isSuccess == true) {
            finalResult = tempResult
        }

        return finalResult
    }

    open func clear<K>(_ key: K) -> StorageResult where K : Hashable {
        let validTuple = validateInput(key, value: nil)

        switch (validTuple.storeToUse) {
        case .userDefaultStore:
            return clearUDS(key as! UnsecureItemType)
        case .keychainStore:
            return clearKey(key as! SecureItemType)
        case .unknownStore:
            return StorageResult.failure(validTuple.error!)
        }
    }

    // get the key
    open func get<K>(_ key: K, valueType: SettingType) -> StorageResult where K : Hashable {
        let validTuple = validateInput(key, value: nil)

        switch (validTuple.storeToUse) {
        case .userDefaultStore:
            return getUDS(key as! UnsecureItemType, valueType: valueType)
        case .keychainStore:
            if (valueType != SettingType.string &&
                valueType != SettingType.object &&
                valueType != SettingType.nsDictionary) {
                log(error: "Invalid valueType (\(valueType)) for key (\(key)) during keychain retrieval.")
                let error = AWError.SDK.Tunnel.Storage.unknownKeychainType.error
                return StorageResult.failure(error)
            }
            return getKey(key as! SecureItemType, valueType: valueType)
        case .unknownStore:
            return StorageResult.failure(validTuple.error!)
        }
    }

    open func set<K, V>(_ key: K, value: V) -> StorageResult where K : Hashable, V : Any {
        let validTuple = validateInput(key, value: value)

        switch (validTuple.storeToUse) {
        case .userDefaultStore:
            return setUDS(key as! UnsecureItemType, value: value)

        case .keychainStore:
            if value is NSDictionary {
                return setKey(key as! SecureItemType, value: value as! NSDictionary)
            } else if (value is Data) {
                return setKey(key as! SecureItemType, value: value as! Data)
            } else if (value is String) {
                return setKey(key as! SecureItemType, value: value as! String)
            } else {
                return StorageResult.failure(validTuple.error!)
            }

        case .unknownStore:
            return StorageResult.failure(validTuple.error!)
        }
    }

    // MARK: - Internal
    // MARK: Properties
    internal var keychainStore = KeychainSettings.sharedInstance
    internal var userDefaultsStore = UserDefaultSettings.sharedInstance

    private init() {}

    // MARK: - Private

    /// Helper Alias for validation
    typealias ValidationTuple = (error: NSError?, storeToUse: InternalStore)

    // MARK: Enums
    /// Expandable enum of the applicable stores
    enum InternalStore {
        case userDefaultStore
        case keychainStore
        case unknownStore
    }

    // MARK: Methods
    /// Helper Method to validate any of the generic input
    fileprivate func validateInput<T>(_ key: T, value: Any?) -> ValidationTuple where T : Hashable {
        // UserDefaultSettings
        if (key is UnsecureItemType) {
            return (nil, InternalStore.userDefaultStore)
        }

        // KeychainSettings
        if (key is SecureItemType) {
            if (value != nil && (value is String || value is NSData || value is NSDictionary)) {
                return (nil, InternalStore.keychainStore)
            } else if (value == nil) {
                return (nil, InternalStore.keychainStore)
            }
        }

        // Parameter fail
        var errorDescription = "Invalid Parameter : key (\(key))"
        if (value != nil) {
            errorDescription += " value (\(value))"
        }
        log(error: "Invalid Parameter : key (\(key)) value (\(value)) encountered during keychain input validation")
        let error = AWError.SDK.Tunnel.Storage.keychainError.error
        return (error, InternalStore.unknownStore)
    }

    // MARK: UserDefaultSettings Wrappers

    /// Helper Method to clear key from the UserDefaultSettings store
    fileprivate func clearUDS(_ key: UnsecureItemType) -> StorageResult {
        userDefaultsStore.clearValue(key.key)
        // Check to see if we were successful
        if let value = userDefaultsStore.objectForKey(key.key) {
            log(error: "Unale to clear value for (\(key)/<\(value)>) in UserDefaults.")
            let error = AWError.SDK.Tunnel.Storage.userDefaultSettingsError.error
            return StorageResult.failure(error)
        }
        return StorageResult.success(nil)

    }

    /// Helper Method to get date from key from the UserDefaultSettings store
    fileprivate func getUDS(_ key: UnsecureItemType, valueType: SettingType) -> StorageResult {
        var result: StorageType? = nil

        switch (valueType) {
        case .bool:
            if let rBool = userDefaultsStore.boolForKey(key.key) {
                result = rBool.storageType
            }
        case .double:
            if let rDouble = userDefaultsStore.doubleForKey(key.key) {
                result = rDouble.storageType
            }
        case .float:
            if let rFloat = userDefaultsStore.floatForKey(key.key) {
                result = rFloat.storageType
            }
        case .integer:
            if let rInt = userDefaultsStore.integerForKey(key.key) {
                result = rInt.storageType
            }
        case .string:
            if let rString = userDefaultsStore.stringForKey(key.key) {
                result = rString.storageType
            }
        case .url:
            if let rURL = userDefaultsStore.urlForKey(key.key) {
                result = rURL.storageType
            }
        case .object:
            if let rObject = userDefaultsStore.objectForKey(key.key) {
                result = StorageType.stObject(rObject)
            }
        default:
            log(error: "UDS storage triggered with unsupported type: \(valueType) for key \(key)")
        }

        if (result == nil) {
            log(warning: "Unable to find value for key \(key) in UDS")
            let error = AWError.SDK.Tunnel.Storage.userDefaultSettingsError.error
            return StorageResult.failure(error)
        }
        return StorageResult.success(result)
    }

    /// Helper Method to set value for key in the UserDefaultSettings store
    fileprivate func setUDS<V>(_ key: UnsecureItemType, value: V) -> StorageResult where V : Any {
        let valueToSave: StorageType

        // Convert strongly
        if (value is Bool) {
            valueToSave = (value as! Bool).storageType
        } else if (value is Double) {
            valueToSave = (value as! Double).storageType
        } else if (value is Float) {
            valueToSave = (value as! Float).storageType
        } else if (value is Int) {
            valueToSave = (value as! Int).storageType
        } else if (value is String) {
            valueToSave = (value as! String).storageType
        } else if (value is URL) {
            valueToSave = (value as! URL).storageType
        } else {
            valueToSave = StorageType(value as AnyObject)
        }

        let isSuccess = userDefaultsStore.set(valueToSave, forKey: key.key)

        if (isSuccess) {
            return StorageResult.success(nil)
        }

        log(warning: "Unable to save: key (\(key)) value (\(value)) to UDS")
        let error = AWError.SDK.Tunnel.Storage.userDefaultSettingsError.error
        return StorageResult.failure(error)
    }

    fileprivate func clearSharedKeychain() -> StorageResult {
        let keychainResult = self.keychainStore.clearSharedKnownSecureItems()

        switch (keychainResult) {
        case .failure(let error):
            return StorageResult.failure(error)
        default:
            return StorageResult.success(nil)
        }
    }

    /**
     Privately clear safe to overwrite shared keychain data from the keychain

     The current exception from total clear of shared secure values, is shared Device UDID

     - Returns: the result from the keycahin modification
     */
    fileprivate func safelyClearSharedKeychain() -> StorageResult {
        let keychainResult = self.keychainStore.safelyClearSharedKnownSecureItems()

        switch (keychainResult) {
        case .failure(let error):
            return StorageResult.failure(error)
        default:
            return StorageResult.success(nil)
        }
    }

    // MARK: KeychainSettiners Wrappers
    /// Helper Method to convert the KeychainResults to the StorageResult
    fileprivate func convertKeychainResult<T>(_ keychainResult: KeychainResults<T>) -> StorageResult {
        
        switch (keychainResult) {
        case .success(let value):
            let stReturn: StorageType?
            
            if let valueDict = value as? NSDictionary {
                return StorageResult.success(StorageType(valueDict))
            }
            
            if let valueData = value as? Data {
                return StorageResult.success(StorageType(valueData))
            }

            if let valueData = value as? NSData {
                return StorageResult.success(StorageType(valueData))
            }

            
            if let valueString = value as? String {
                return StorageResult.success(StorageType(valueString))
            }

            if let valueString = value as? NSString {
                return StorageResult.success(StorageType(valueString))
            }

            
            if let value = value {
                if (value is NSDictionary) {
                    return StorageResult.success(StorageType(value as! NSDictionary))
                }
                
                if (value is Data) {
                    stReturn = StorageType(value as! Data)
                }
                
                else if (value is String) {
                    stReturn = StorageType(value as! String)
                } else {
                    stReturn = nil
                }
            } else {
                stReturn = nil
            }
            return StorageResult.success(stReturn)
        
        case .failure(let error):
            return StorageResult.failure(error)
        }
    }

    /// Helper Method to clear key from the Keychain store
    fileprivate func clearKey(_ key: SecureItemType) -> StorageResult {
        let keychainResult = keychainStore.clearValue(key)

        return convertKeychainResult(keychainResult)
    }

    /// Helper Method to retrieve String for key from the Keychain store
    fileprivate func getKey(_ key: SecureItemType,
        valueType: SettingType) -> StorageResult {
            switch (valueType) {
            case .string:
                let keychainResult = keychainStore.value(key)
                return convertKeychainResult(keychainResult)
            case .object:
                let keychainResult = keychainStore.data(key)
                return convertKeychainResult(keychainResult)
            case .nsDictionary:
                let keychainResult = keychainStore.dictionary(key)
                return convertKeychainResult(keychainResult)
            default:
                log(error: "Requesting invalid type from the keychain store: \(valueType)")
                return StorageResult.failure(AWError.SDK.Tunnel.Storage.keychainError.error)
            }
    }

    /// Helper Method to set value for key in the Keychain store
    fileprivate func setKey(_ key: SecureItemType, value: Data) -> StorageResult {
        let keychainResult = keychainStore.setData(value, itemType: key)
        return convertKeychainResult(keychainResult)
    }

    fileprivate func setKey(_ key: SecureItemType, value: String) -> StorageResult {
        let keychainResult = keychainStore.setValue(value, itemType: key)
        return convertKeychainResult(keychainResult)
    }

    fileprivate func setKey(_ key: SecureItemType, value: NSDictionary) -> StorageResult {
        let keychainResult = keychainStore.setDictionary(value, itemType: key)
        return convertKeychainResult(keychainResult)
    }

}
