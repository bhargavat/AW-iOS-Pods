//
//  ContentServices.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWCrypto
import AWError
import AWHelpers
import AWServices
import AWStorage


internal extension ConsoleVersion {
    var versionString: String {
        return [self.major, self.minor, self.patch].flatMap(String.init).joined(separator: ".")
    }
}

public enum Extensions {
    public enum ContentServices { }
}

public extension Data {
    @inline(__always)
    public func md5() -> Data? {
        return self.md5
    }

    @inline(__always)
    public func sha1() -> Data? {
        return self.sha1
    }

    @inline(__always)
    public func sha256() -> Data? {
        return self.sha256
    }

    @inline(__always)
    public func sha512() -> Data? {
        return self.sha512
    }
}

public extension Data {
    public func aesEncrypt(key: Data) throws -> Data {
        guard let encryptedData = try SecureDataMessage.defaultMessage.encrypt(self, key: key) else {
            throw AWError.SDK.InvalidOperations.emptyData.error
        }
        return encryptedData
    }
    
    public func aesDecrypt(key: Data) throws -> Data {
        guard let decryptedData = try SecureDataMessage.decrypt(self, key: key) else {
            throw AWError.SDK.InvalidOperations.emptyData.error
        }
        return decryptedData
    }
}

public extension URL {
    public func encrypt(key: Data, to destination: URL, with completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        guard var fileCryptor = AWCrypto.FileCryptor(source: self.path, destination: destination.path, key: key) else {
            completion(false, nil)
            return
        }

        fileCryptor.encrypt(with: completion)
    }
    
    public func decrypt(key: Data, to destination: URL, with completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        guard var fileCryptor = AWCrypto.FileCryptor(source: self.path, destination: destination.path, key: key) else {
            completion(false, nil)
            return
        }

        fileCryptor.decrypt(with: completion)
    }
}

public extension Data {
    public init(count: Int, randomize: Bool = false) {
        if randomize {
            self.init(Data.randomData(count: count))
        } else {
            self.init(count: count)
        }
    }
}

public extension URLRequest {
    var signed: URLRequest? {
        guard
            let mutableRequest = (self as NSURLRequest).mutableCopy() as? NSMutableURLRequest,
            let sdkHMACSigner = AWHMACSigner.sharedSigner(),
            sdkHMACSigner.signRequest(mutableRequest)
        else {
            return nil
        }
        let signedURLRequest = mutableRequest as URLRequest
        return signedURLRequest
    }
}

public extension Extensions.ContentServices {

    public enum Network {
        public static var currentNetworkIsReachable: Bool {
            guard let reachability = Reachability.forInternetConnection else { return false }
            return reachability.currentReachabilityStatus != .notReachable
        }
    }
    
    public enum KeyChain {
        public static func get(group: String, key: String) -> Data? {
            return AWKeychain().get(group, key: key)
        }
        
        public static func set(group: String, key: String, value: Data?) -> Bool {
            return AWKeychain().set(group, key: key, value: value)
        }
    }

    public enum Crypto {
        public static func encrypt(_ data: Data) throws -> Data {
            var encryptionError: NSError?
            guard
                let encryptedData = AWController.sharedInstance.encrypt(data, error: &encryptionError),
                encryptionError == nil
            else {
                throw encryptionError ?? AWError.SDK.InvalidOperations.emptyData.error
            }
            return encryptedData
        }

        public static func decrypt(_ data: Data) throws -> Data {
            var decryptionError: NSError?
            guard
                let decryptedData = AWController.sharedInstance.decrypt(data, error: &decryptionError),
                decryptionError == nil
            else {
                throw decryptionError ?? AWError.SDK.InvalidOperations.emptyData.error
            }
            return decryptedData
        }
    }

    public enum Console {
        public static var version: String {
            return AWController.sharedInstance.context.consoleVersion?.versionString ?? "0.0.0.0"
        }
    }
    
    public enum Device {
        public static var info: (type: String, id: String) {
            guard let config = AWController.sharedInstance.dataStore.deviceServices?.config else {
                return (type: "", id: "")
            }
            return (type: config.deviceType, id: config.deviceId)
            
        }
    }
    
    public enum EscrowedKey {
        public static func fetchForContent(enrollmentUserId : String,
                                           completionHandler: @escaping (_ keyData: Data?, _ error: NSError?) -> Void) {
            AWController.sharedInstance.dataStore.deviceServices?.fetchEscrowedKey(.content, enrollmentUserId: enrollmentUserId, completionHandler: completionHandler)
        }
        
        public static func storeForContent(escrowKeyData    : Data,
                                           enrollmentUserId : String,
                                           completionHandler: @escaping (_ isEscrowKeyStored: Bool, _ error: NSError?) -> Void) -> Void {
            
            struct ContentEscrowKey: EscrowKey {
                let usage: AWServices.KeyStoreUser = .content
                let algorithm: AWServices.KeyAlgorithm = .AES256
                let keyData: Data
                
                init(key: Data) {
                    self.keyData = key
                }
            }
            
            let escrowKey = ContentEscrowKey(key: escrowKeyData)
            AWController.sharedInstance.dataStore.deviceServices?.storeKeyWithEscrowService(EscrowStoreKey: escrowKey, enrollmentUserId: enrollmentUserId, completionHandler: completionHandler)
        }
    }
}
