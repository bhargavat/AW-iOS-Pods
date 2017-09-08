//
//  SecureChannelConfigurationStore.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWStorage

fileprivate let SecureChannelConfigurationManagerSerialQueue = DispatchQueue(label: "com.vmware.air-watch.secure-channel.config.serial")

class SDKSecureChannelConfigurationManager: SecureChannelConfigurationManager, ConfigurationProvider, KeyValueStorageProvider {
    var keyChainGroup = "SecureChannelConfigurationStore"
    var deviceID: String
    var airWatchServerURL: String
    var keychainStore = AWKeychain()
    let itemQueryProvider: KeyValueStoreItemQueryProvider = .nonSharedItem
    
    init(url: String, deviceIdentifier: String) {
        self.deviceID = deviceIdentifier
        self.airWatchServerURL = url
    }
    
    static func configurationManager(url: String, deviceIdentifier: String) -> SDKSecureChannelConfigurationManager? {
        let configurationManager = SDKSecureChannelConfigurationManager(url: url, deviceIdentifier: deviceIdentifier)
        return configurationManager
    }
    
    func get(key: String) -> Data? {
        let valueFromKeychain = self.keychainStore.get(keyChainGroup, key: key)
        log(debug: "Retrieved Secure Channel Configuration for host:\(key) : \(valueFromKeychain != nil ? "true" : "false")")
        return valueFromKeychain
    }
    
    func save(key: String, data: Data?) {
        let didSave = self.keychainStore.set(keyChainGroup, key: key, value: data)
        log(debug: "Saved Secure Channel Configuration for host:\(key) : \(didSave)")
    }
    
    public func clearAll() {
    }

    var configurationSecurityPassword: String? {
        var keychainStore = KeychainDataStore()
        
        let existingKey: String?  = keychainStore.fetch(itemQueryProvider.ApplicationSecureChannelConfigurationObfuscationKey)
        if existingKey != nil {
            return existingKey
        }
        
        let generatedKey = UUID().uuidString
        _ = keychainStore.set(itemQueryProvider.ApplicationSecureChannelConfigurationObfuscationKey, value: generatedKey)
        return generatedKey
    }
}
