//
//  KeyEscrowAPI.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork
import AWError

extension AWServices {
    public enum KeyStoreUser: Int {
        case content = 1
        case sdk = 2
    }

    public enum KeyAlgorithm: String {
        case Unknown    = "Unknown"
        case Other      = "Other"
        case AES128     = "AES128"
        case AES192     = "AES192"
        case AES256     = "AES256"
        case DES        = "DES"
        case TripleDES  = "3DES"
    }
}

public protocol EscrowKey {
    var usage: AWServices.KeyStoreUser { get }
    var algorithm: AWServices.KeyAlgorithm { get }
    var keyData: Data { get }
}

internal class EscrowKeyStoreEndpoint: DeviceServicesEndpoint {

    class PayloadKeys {
        static let deviceType               = "DeviceType"
        static let deviceUDID               = "Uid"
        static let enrollmentUserID         = "EnrollmentUserId"
        static let keyRetrievalUsageType    = "DeviceKeyUsage"
        static let keyAlgorithm             = "Algorithm"
        static let keySize                  = "KeySize"
        static let encodedKey               = "Base64EncodedKey"
    }

    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = "deviceservices/awmdmsdk/v1/platform/\(config.deviceType)/uid/\(config.deviceId)/keystore/storekey"
    }

    fileprivate func prepareStoreKeyPayload(_ key: EscrowKey, enrollmentUserID: String) -> Data? {
        let base64Key = key.keyData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
        var payload = [String: AnyObject]()
        payload[PayloadKeys.deviceType] = config.deviceType as AnyObject?
        payload[PayloadKeys.deviceUDID] = config.deviceId as AnyObject?
        payload[PayloadKeys.enrollmentUserID] = enrollmentUserID as AnyObject?
        payload[PayloadKeys.keyRetrievalUsageType] = key.usage.rawValue as AnyObject?
        payload[PayloadKeys.keyAlgorithm] = key.algorithm.rawValue as AnyObject?
        payload[PayloadKeys.keySize] = base64Key.characters.count as AnyObject?
        payload[PayloadKeys.encodedKey] = base64Key as AnyObject?
        return try? JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions(rawValue: 0))
    }

    public func storeKeyInEscrowServer(_ key: EscrowKey, enrollmentUserID: String, completionHandler: @escaping (_ isEscrowKeyStored: Bool, _ error: NSError?) -> Void) -> Void {
        guard self.endpointURL != nil else {
            completionHandler(false, AWError.SDK.Service.General.invalidHTTPURL("\(hostUrlString), \(serviceEndpoint)").error)
            return
        }

        let payloadData = self.prepareStoreKeyPayload(key, enrollmentUserID: enrollmentUserID)

        self.POST(payloadData) { (rsp: CTLJSONObject?, error: NSError?) in
            guard error == nil else {
                completionHandler(false, error)
                return
            }

            completionHandler(true, nil)
        }
    }
}
