//
//  LegacySecureChannel.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCMWrapper
import AWCrypto
import AWHelpers

/**
 Used primarily for the SDK's secure channel migration of private/public/server keys or certificates. Use for migrating keys/certificates which were saved previously in pre 17.1
 */
public class SecureChannelConfigurationManagerMigration {
    // Hard coded strings from 5.x.x
    let publicKeyString = "c9e8r7t"
    let serverCertificateString = "s1e3r5v7e9r"
    let privateKeyString = "k1e2yp3riv"
    
    let deviceID: String
    let hostname: String
    
    public init(deviceID: String, hostname: String) {
        self.deviceID = deviceID
        self.hostname = hostname
    }
    
    /**
     Migrate data from pre 17.1 which calls the internal function (setSecureChannelConfig) of the  configurationManager to save the SecureChannelConfiguration
     
     @param publicData Raw encrypted public data
     @param privateData Raw encrypted private data encrypted in pkcs8 where the passphrase is in data format
     @param serverData Raw encrypted server data
     @param url If nil, the SDK will later attempt to resolve the secure channel endpoint url by attempting to do a handshake
     @param configurationManager Must implment the protocols SecureChannelConfigurationManager, KeyValueStorageProvider, and ConfigurationProvider
     */
    public func migrate(publicData: Data,
                        privateData: Data,
                        serverData: Data,
                        secureChannelEndpointURL: String?,
                        configurationManager: SecureChannelConfigurationManager&KeyValueStorageProvider&ConfigurationProvider) {
        let privateKeyPassphrase = Data.randomData(count: SecureChannelClientPrivateKeyPasswordDataLength).base64EncodedString()
        guard let decryptedPublicData = self.decryptPublicKey(rawPublicKeyData: publicData),
                let decryptedPrivateData = self.decryptPrivateKey(rawPrivateKeyData: privateData, passphrase: privateKeyPassphrase),
                let decryptedServerData = self.decryptServerKey(rawServerData: serverData) else {
                log(error: "Could not migrate the secure channel public/private/server keys")
                return
        }
        
        let secureChannelConfig = SecureChannelConfiguration()
        secureChannelConfig.URLString = secureChannelEndpointURL
        secureChannelConfig.serverCertificate = decryptedServerData
        secureChannelConfig.clientCertificate = decryptedPublicData
        secureChannelConfig.clientPrivateKey = decryptedPrivateData
        secureChannelConfig.clientPrivateKeyPassphrase = privateKeyPassphrase
        
        configurationManager.setSecureChannelConfig(hostname: hostname, configuration: secureChannelConfig)
    }
    
    func decryptPublicKey(rawPublicKeyData: Data) -> Data?{
        guard let publicKey = (publicKeyString+"com.key").toData()?.sha256 else {
            return nil
        }
        guard let ret = try? CipherHelper.decrypt(rawPublicKeyData, key: publicKey) else {
            return nil
        }
        return ret
    }
    
    func decryptPrivateKey(rawPrivateKeyData: Data, passphrase: String) -> Data? {
        guard let one = privateKeyString.toData()?.sha256,
            let two = "%@com.key".toData()?.sha256 else {
                log(error: "Failed")
                return nil
        }
        
        let onePtr = [UInt8](one)
        let twoPtr = [UInt8](two)
        var modifiedEncKey: [UInt8] = [UInt8](one)
        
        var counter = 0
        for i in onePtr {
            modifiedEncKey[counter] = i^twoPtr[counter]
            counter += 1
        }
        
        
        guard let calculatedKey = Data(bytes: modifiedEncKey).sha256,
            let decryptedPrivateData = try? CipherHelper.decrypt(rawPrivateKeyData, key: calculatedKey),
            let ret = self.changePassphrase(privateKey: decryptedPrivateData, newPassphrase: passphrase) else {
            return nil
        }
        
        return ret
    }
    
    func decryptServerKey(rawServerData: Data) -> Data? {
        guard let serverKey = (serverCertificateString+"com.key").toData()?.sha256 else {
            return nil
        }
        guard let ret = try? CipherHelper.decrypt(rawServerData, key: serverKey) else {
            return nil
        }
        return ret
    }
    
    // This is a custom function to change passphrase using data to use a new passphrase of type string
    func changePassphrase(privateKey: Data?, newPassphrase: String) -> Data? {
        if let oldPassphrase = (deviceID+"s!a2l#t").toData()?.sha256,
            let privateKey = privateKey {
            if let newPKCS8DER = AWUpdateKeyPassphrase(privateKey, oldPassphrase, newPassphrase) {
                return newPKCS8DER
            }
        }
        return nil
    }
}

fileprivate struct CipherHelper: CipherMessage {
    var algorithm: CipherAlgorithm
    var blockMode: BlockCipherMode
    var ivSize: Int
}

fileprivate extension String {
    func toData() -> Data? {
        return self.data(using: String.Encoding.utf8)
    }
}
