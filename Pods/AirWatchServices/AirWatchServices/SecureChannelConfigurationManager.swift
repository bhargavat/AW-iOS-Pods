//
//  SecureChannelConfigurationManager.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCMWrapper
import AWHelpers
import AWError
import AWCrypto

public protocol KeyValueStorageProvider {
    func save(key: String, data: Data?)
    func get(key: String) -> Data?
}

public protocol ConfigurationProvider {
    var deviceID: String { get }
    var airWatchServerURL: String { get }
    var configurationSecurityPassword: String? { get }
}

let SecureChannelConfigurationManagerSerialQueue = DispatchQueue(label: "com.vmware.air-watch.secure-channel.config.serial")
let SecureChannelClientPrivateKeyPasswordDataLength = 32

fileprivate struct SecureChannelConfigurationCache {
    private static var cache: [String: SecureChannelConfiguration] = [:]

    static func retrieveConfiguration(host: String) -> SecureChannelConfiguration? {
        return SecureChannelConfigurationCache.cache[host]
    }

    static func cacheConfiguration(host: String, configuration: SecureChannelConfiguration?) {
        SecureChannelConfigurationCache.cache[host] = configuration
    }

    static func clear() {
        SecureChannelConfigurationCache.cache = [:]
    }
}

public extension SecureChannelConfigurationManager where Self: KeyValueStorageProvider, Self:ConfigurationProvider {

    internal func getSecureChannelConfig(hostname: String) -> SecureChannelConfiguration {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.vmware.air-watch.schannel-config"
        let secureChannelConfigKey = "\(bundleIdentifier).\(hostname)"
        if let cachedConfig = SecureChannelConfigurationCache.retrieveConfiguration(host: secureChannelConfigKey) {
            return cachedConfig
        }

        var config = SecureChannelConfiguration()
        if let hostSecureChannelData = self.get(key: secureChannelConfigKey),
            let decryptedConfiguration = self.decyrptConfiguration(data: hostSecureChannelData) {
            config = decryptedConfiguration
        }

        // If a passphrase is not set (Older version of Workspace used a version of AirwatchServices which did not have a passphrase), then it is necessary to add a passphrase. If nil is returned for AWUpdateKeyPassphrase then a passphrase is set and we should return the configuration object with the modified client private key.
        guard let privateKey = config.clientPrivateKey, config.clientPrivateKeyPassphrase == nil else {
            SecureChannelConfigurationCache.cacheConfiguration(host: secureChannelConfigKey, configuration: config)
            return config
        }
        
        let privateKeyPassphrase = Data.randomData(count: SecureChannelClientPrivateKeyPasswordDataLength).base64EncodedString()
        if let pkcs8PrivateKey = AWUpdateKeyPassphrase(privateKey, nil, privateKeyPassphrase) {
            log(info: "Created Privatekey password for secure channel configuration")
            config.clientPrivateKey = pkcs8PrivateKey
            config.clientPrivateKeyPassphrase = privateKeyPassphrase
        }
        self.setSecureChannelConfig(hostname: hostname, configuration: config)
        return config
    }

    internal func setSecureChannelConfig(hostname: String, configuration: SecureChannelConfiguration?) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.vmware.air-watch.schannel-config"
        let secureChannelConfigKey = "\(bundleIdentifier).\(hostname)"
        SecureChannelConfigurationCache.cacheConfiguration(host: secureChannelConfigKey, configuration: configuration)

        guard let config = configuration else {
            self.save(key: secureChannelConfigKey, data: nil)
            return
        }

        let securedObject = self.encyrptConfiguration(configuration: config)
        self.save(key: secureChannelConfigKey, data: securedObject)
    }


    public func secureChannelURL(forHost hostname: String) -> URL? {
        if let urlString = self.getSecureChannelConfig(hostname: hostname).URLString {
            return URL(string: urlString)
        }
        return nil
    }
    public func secureChannelClientPrivateKeyPassphrase(forHost hostname: String) -> String? {
        if let passphrase = self.getSecureChannelConfig(hostname: hostname).clientPrivateKeyPassphrase {
            return passphrase
        }
        return nil
    }

    public func setSecureChannelURL(forHost hostname: String, channelURL: URL) {
        let secureChannelConfig = self.getSecureChannelConfig(hostname: hostname)
        secureChannelConfig.URLString = channelURL.absoluteString
        setSecureChannelConfig(hostname: hostname, configuration: secureChannelConfig)
    }

    public func secureChannelServerCertificate(forHost hostname: String) -> Data? {
        return self.getSecureChannelConfig(hostname: hostname).serverCertificate
    }

    public func setSecureChannelServerCertificate(forHost hostname: String, unverifiedServerCertificateData: Data) throws {
        let secureChannelConfig = getSecureChannelConfig(hostname: hostname)
        //not verifying certificate for now.
        guard let secureChannelServerX509 = AWX509Wrapper(certificateData: unverifiedServerCertificateData) else {
            throw AWError.SDK.SecureChannel.ConfigurationManager.serverCertificateCorrupted(hostname)
        }
        let secureChannelServerCAX509 = AWX509Wrapper(certificateData: secureChannelRootCertificate())
        guard let x509 = secureChannelServerCAX509 , secureChannelServerX509.verify(withRootCertificate: x509) else {
            throw AWError.SDK.SecureChannel.ConfigurationManager.serverCertificateValidationFailed(hostname)
        }
        log(info: "Secure Channel certificate verification success")
        secureChannelConfig.serverCertificate = unverifiedServerCertificateData
        setSecureChannelConfig(hostname: hostname, configuration: secureChannelConfig)
    }

    fileprivate func generateKeyPair(forHost hostname: String) -> Bool {
        if self.deviceID.characters.count == 0 || self.airWatchServerURL.characters.count == 0 {
            return false
        }

        var keyPairGenerated = false
        SecureChannelConfigurationManagerSerialQueue.sync {
            let secureChannelConfig = self.getSecureChannelConfig(hostname: hostname)
            if (secureChannelConfig.clientCertificate != nil || secureChannelConfig.clientPrivateKey != nil) {
                return
            }
            
            let temporaryIdentifier = "com.vmware.air-watch.secure-channel-certitificates"
            guard
                let keypair = try? SecurityKeyPair.generate(2048, identifier: temporaryIdentifier , persistent: false),
                let keypairPublicKey = keypair.publicKey,
                let keypairPrivateKey = keypair.privateKey,
                let publicKey = Data.publicKeyData(keypairPublicKey),
                let privateKey = Data.privateKeyData(keypairPrivateKey)
                else {
                    return
                }
            SecurityKeyPair.clear(temporaryIdentifier)
            
            let deviceRootX509Data = AWPKCS12Helper.certificateData(fromPKCS12Data: getDeviceRootCertP12Data(),
                                                                    password: resolveDeviceRootP12password())
            let privateKeyPassword = Data.randomData(count: SecureChannelClientPrivateKeyPasswordDataLength).base64EncodedString()
            let privateKeyWithPassphrase = AWUpdateKeyPassphrase(privateKey, nil, privateKeyPassword)
            secureChannelConfig.clientPrivateKey = privateKeyWithPassphrase
            secureChannelConfig.clientPrivateKeyPassphrase = privateKeyPassword
            
            
            let devicePrivateKey = AWPKCS12Helper.privateKeyData(fromPKCS12Data: getDeviceRootCertP12Data(),
                                                                 password: resolveDeviceRootP12password())
            let deviceX509 = AWX509Wrapper(certificateData: deviceRootX509Data)
            let bundleID = Bundle.main.bundleIdentifier ?? "com.vmware.air-watch.schannel-config"
            let deviceCertAttrs = [
                kAWCertificateSubjectName: "\(bundleID),\(self.airWatchServerURL)",
                kAWCertificateUserID: self.deviceID
            ]
            
            guard let deviceCert = AWX509Wrapper(attributes: deviceCertAttrs, publicKey: publicKey as Data?),
                let signedClientCertificateData = deviceCert.sign(withIssuer: deviceX509, privateKey: devicePrivateKey, password: resolveDeviceRootP12password()),
                let signedDeviceCert = AWX509Wrapper(certificateData: signedClientCertificateData) else {
                    fatalError("Can not generate and sign device certificate")
            }
            let verified = signedDeviceCert.verify(withRootCertificate: deviceX509)
            assert(verified, "Can not verify generated and signed certificate")
            secureChannelConfig.clientCertificate = signedClientCertificateData
            self.setSecureChannelConfig(hostname: hostname, configuration: secureChannelConfig)
            keyPairGenerated = true
        }
        return keyPairGenerated
    }

    fileprivate func getClientCredentials(forHost hostname: String, targetClosure: (_ configuration: SecureChannelConfiguration) -> Data?) -> Data {
        let config =  self.getSecureChannelConfig(hostname: hostname)
        if let data = targetClosure(config) {
            return data
        } else if self.generateKeyPair(forHost: hostname) {
            return getClientCredentials(forHost: hostname, targetClosure: targetClosure)
        }

        return Data()
    }

    public func secureChannelClientCertificate(forHost hostname: String) -> Data {
        return self.getClientCredentials(forHost: hostname) { (configuration) in
            return configuration.clientCertificate
        }
    }

    public func secureChannelClientPrivateKey(forHost hostname: String) -> Data {
        return self.getClientCredentials(forHost: hostname) { (configuration) in
            return configuration.clientPrivateKey
        }
    }

    public func resetClientCredentials(forHost hostname: String) -> Void {
        setSecureChannelConfig(hostname: hostname, configuration: nil)
    }
}

extension Array where Element: Integer {
    mutating func rotate(_ positions: Int) {
        let shiftPositions = positions % self.count
        var result:[Element] = []
        let first = self.count - shiftPositions
        let last = shiftPositions
        result.append(contentsOf: self.dropFirst(first))
        result.append(contentsOf: self.dropLast(last))
        self = result
    }
    
    mutating func xor(_ array: [Element]) {
        guard self.count == array.count else { return }
        
        for (index, element) in array.enumerated() {
            self[index] = self[index] ^ element
        }
    }
}

let p1 :[UInt8] = [55, 37, 76, 114, 88, 107, 77, 38, 88, 33, 117, 50, 102, 114, 98, 33]
let p2 :[UInt8] = [61, 99, 104, 95, 112, 87, 88, 70, 61, 50, 100, 119, 97, 52, 57, 53]
let p3 :[UInt8] = [42, 43, 61, 117, 98, 37, 54, 82, 118, 104, 53, 75, 86, 38, 122, 87]
let p4 :[UInt8] = [80, 107, 102, 66, 101, 71, 88, 118, 65, 84, 69, 117, 103, 84, 51, 114]
let p5 :[UInt8] = [83, 67, 89, 63, 54, 64, 97, 98, 72, 100, 109, 94, 71, 69, 65, 115]
let p6 :[UInt8] = [104, 90, 114, 95, 70, 83, 85, 72, 52, 109, 67, 42, 51, 82, 69, 106]
let p7 :[UInt8] = [229, 195, 105, 100, 87, 131, 213, 106, 182, 78, 221, 180, 190, 211, 205, 36]

let saltData: Data = {
    let modoperand: UInt8 = 16

    var first_half = p1
    p3.forEach { (element) in
        first_half.xor(p5)
        first_half.rotate(Int(element % modoperand))
    }
    
    var second_half = p2
    p4.forEach { (element) in
        second_half.xor(p6)
        second_half.rotate(Int(element % modoperand))
    }
    
    var final = first_half+second_half
    return Data(bytes: final)
}()

struct KeyGenerator: PassphraseDerivator { }

struct ConfigurationCryptor: CipherMessage,PassphraseDerivator {
    var algorithm: CipherAlgorithm
    var blockMode: BlockCipherMode
    var ivSize: Int
}


// To avoid having a company define these implmentations as part of the protocol
internal extension SecureChannelConfigurationManager where Self: KeyValueStorageProvider, Self:ConfigurationProvider  {

    @inline(__always)
    internal func derivedPasscodeForSecureChannelConfiguration(configPassword: String?) -> Data? {
        let password = configPassword ?? ""
        let derivator = KeyGenerator()
        if let passwordData = try? derivator.deriveKey(password, saltData: saltData){
            return passwordData
        }
        var passcodeData = password.data(using: .utf8) ?? Data()
        passcodeData.append(saltData)
        return passcodeData
    }
    
    /**
     Encrypt/Decrypt a blob of data (SecureChannelConfiguration) so to be passed to the get/save functions which are defined by the class which has extended the SecureChannelConfigurationManager where Self is KeyValueStorageProvider and ConfigurationProvider.
     
     This is inline so to make it harder on someone trying to call this function directly to encrypt/decrypt data
     */
    @inline(__always)
    internal func encyrptConfiguration(configuration: SecureChannelConfiguration) -> Data? {
        let data = NSKeyedArchiver.archivedData(withRootObject: configuration)
        if let encryptionPassword = self.derivedPasscodeForSecureChannelConfiguration(configPassword: self.configurationSecurityPassword),
            let encryptedConfigurationData = try? ConfigurationCryptor.defaultMessage.encrypt(data, key: encryptionPassword) {
            return encryptedConfigurationData
        }

        return data
    }
    
    @inline(__always)
    internal  func decyrptConfiguration(data: Data) -> SecureChannelConfiguration? {
        // WorkspaceOne started using an older version of SecureChannelConfigurationManager which did not encrypt the whole object.
        // Since we are unsure which version of data it received from the self.get, first attempt to unarchive the object.
        // If unarchiving directly fails we know that the data object has been encrypted and must be decrypted and then unarchived.
        if let unarchivedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data as NSData),
            let config = unarchivedObject as? SecureChannelConfiguration {
            return config
        }
        
        log(info: "Can not decrypt configuration without password Will try with provided password if one exist")
        do {
            if let encryptionPassword = self.derivedPasscodeForSecureChannelConfiguration(configPassword: self.configurationSecurityPassword),
                let decryptedData = try ConfigurationCryptor.decrypt(data, key: encryptionPassword),
                let unarchivedObject = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(decryptedData as NSData),
                let config = unarchivedObject as? SecureChannelConfiguration {
                return config
            }
        } catch let error {
            log(error: "Decryption with provided password failed error:\(error)")
        }
        
        log(info: "Can not decrypt configuration with given password")
        do {
            if let encryptionPassword = self.derivedPasscodeForSecureChannelConfiguration(configPassword: nil),
                let decryptedData = try ConfigurationCryptor.decrypt(data, key: encryptionPassword),
                let unarchivedObject = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(decryptedData as NSData),
                let config = unarchivedObject as? SecureChannelConfiguration {
                return config
            }
        } catch let error {
            log(error: "Decryption with default password failed error:\(error)")
        }

        return nil
    }
}


@inline(__always)
func resolveDeviceRootP12password() -> String {
    let pre = "Jzn7ZPfC6o"
    let final = "AWPayloadReceiveNotification"
    let combinationString = "\(pre)/\(final)"
    var result = ""
    if let combinationData = combinationString.data(using: String.Encoding.utf8)?.sha256 {
        result = combinationData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
    }
    return result
}

@inline(__always)
func getDeviceRootCertP12Data() -> Data {
    let defaultRootCert = "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"
    return Data(base64Encoded: defaultRootCert, options: Data.Base64DecodingOptions(rawValue: 0))!
}

@inline(__always)
func secureChannelRootCertificate() -> Data {
    let serverCA = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tDQpNSUlDMmpDQ0FjS2dBd0lCQWdJUUs4QmJqbWZKZFpkTjg2eUc0aW4rQVRBTkJna3Foa2lHOXcwQkFRVUZBREFvDQpNU1l3SkFZRFZRUURFeDFCYVhKWFlYUmphQ0JFWlhacFkyVWdVMlZ5ZG1salpYTWdVbTl2ZERBZ0Z3MHhNVEV5DQpNVE14T0RRMU5EQmFHQTh5TURZeE1USXhOREU0TkRVME1Gb3dLREVtTUNRR0ExVUVBeE1kUVdseVYyRjBZMmdnDQpSR1YyYVdObElGTmxjblpwWTJWeklGSnZiM1F3Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLDQpBb0lCQVFDUUk3dEZsUVNnbG1tZkM5a0wwRnRoOWM4aVFyTDEwZmRrL3dhZnpUVkdRVS9wazJ4cElUZ2x1ZWUzDQpibkZFYlVrUlBHSTFmYTYwR0hnaDRaM0t5N1daRSt4NEdValBwVHZ5RitPSHBWWGhMZlFRK3hrMGNlaDdRL1Z0DQpRVFNscVBnQVpkNXF4bE9tSHNlVmVkdTdkVWlhOWhZcWJhMFk3cU5wdlJVQVBLcFlQK1UrbFFhTlBkRXA4VVBMDQp4TU1qd1Z5ZitRQjFkVWFKcERoWGFsYkFoa1IxdnVqc0YvVU56WFYrMm41ZG16TWVKeDlwVHB6dU9qWldIOTVSDQpJbkNPRm14R0Q1QmtCODVNbzc1TDNxM3l3ZVRNWUlBbStIdjFUdk5WalBIb1dBSkl5NDVKVDNmQlA1dFc2bEwyDQp6cUNTdG5kdFZpRkF3a0N3R1F3MzBUOE95dElsQWdNQkFBRXdEUVlKS29aSWh2Y05BUUVGQlFBRGdnRUJBRjNYDQp3WEVFQStmTDA1SFR1WFh1RnhobzlkTmIrQ0lZQXgxR3lROXBsdmZYTlhBVGtFcWFCQ0VkRk1OdEg1UWdqcEpqDQpwakk0MWozWkV2b0J3YXU3WkF2RGFKanl4UDlIR0VOQWorOUNUM0pxY0hQNFBGQlhIa2VjRHRNRzA1VWduZmFvDQpJV3l2VWVsclJLT0JwTEFleVBjMWlJTW5UeXBZNFFuSFZCSTRPbDl5TS9GQVd3M2xqSjNMbXZXdkdUK3VzVjJPDQptVkpkRUdSU1hwQTVQdG5CbFp5dkx0QzR3ZGtkS20vdjIybklRVjZRZjZWRnlGVUwrNzM0dXJ1TitKb0lkNVpLDQpidmhkQ2RmNFhVOUg5OGl3aDhjNlc0OGRaR0FUZ29EaEUrZDJFaWxIaWpTbVFPS0FUVXA2bW1DZzF6T3BQdTRjDQpzZHpTNTdpUmNYV3k2MFdndU9VPQ0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQ0K"
    return Data(base64Encoded: serverCA, options: Data.Base64DecodingOptions(rawValue: 0))!
}



