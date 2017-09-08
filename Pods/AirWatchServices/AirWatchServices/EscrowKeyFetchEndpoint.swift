//
//  KeyEscrowAPI.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWNetwork
import Foundation
import AWNetwork
import AWError


internal class EscrowKeyFetchEndpoint: DeviceServicesEndpoint {

    class PayloadKeys {
        static let deviceType        = "DeviceType"
        static let deviceUDID        = "Uid"
        static let enrollmentUserID  = "EnrollmentUserId"
        static let usageRetreive     = "KeyUsage"
        static let encodedKey        = "Base64EncodedKey"
    }

    fileprivate func prepareRetrieveKeyPayload(_ keyUser: AWServices.KeyStoreUser, enrollmentUserID: String) -> Data? {
        var payload = [String: AnyObject]()
        payload[PayloadKeys.deviceType] = config.deviceType as AnyObject?
        payload[PayloadKeys.deviceUDID] = config.deviceId as AnyObject?
        payload[PayloadKeys.enrollmentUserID] = enrollmentUserID as AnyObject?
        payload[PayloadKeys.usageRetreive] = keyUser.rawValue as AnyObject?
        return try? JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions(rawValue: 0))
    }

    public func fetchKeyFromEscrowServer(_ keyUser: AWServices.KeyStoreUser, enrollmentUserId: String, completionHandler: @escaping (_ keytData: Data?, _ error: NSError?) -> Void) -> Void {
        serviceEndpoint = "deviceservices/awmdmsdk/v1/platform/\(config.deviceType)/uid/\(config.deviceId)/keystore/retrievekey/devicekeyusage/\(keyUser.rawValue)/enrollmentuserid/\(enrollmentUserId)"

        guard self.endpointURL != nil else {
            completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL("\(hostUrlString), \(serviceEndpoint)").error)
            return
        }

        let payloadData = self.prepareRetrieveKeyPayload(keyUser, enrollmentUserID: enrollmentUserId)
        self.POST(payloadData) {(rsp: CTLJSONObject?, error: NSError?) in
            guard error == nil else {
                completionHandler(nil, error)
                return
            }
            if let response = rsp?.JSON as? [String: AnyObject],
                let encodedKey = response[PayloadKeys.encodedKey] as? String {
                let data = Data(base64Encoded: encodedKey, options: Data.Base64DecodingOptions(rawValue: 0))
                completionHandler(data, nil)
            } else {
                completionHandler(nil, AWError.SDK.Service.General.invalidJSONResponse.error)
            }

        }

    }
}
