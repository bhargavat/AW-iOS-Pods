//
//  RequestRequeryDeviceStatusEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork
import AWHelpers
import AWError

extension AWServices {
    public enum RequeryType: String {
        case applist        = "applist"
        case deviceInfo     = "deviceinfo"
        case profileInfo    = "profilesinfo"
        case securityInfo   = "securityinfo"
    }
}

internal class RequestRequeryDeviceStatusEndpoint: DeviceServicesEndpoint {
    private var requeryType = AWServices.RequeryType.deviceInfo

    internal func requestRequery(type: AWServices.RequeryType, completion: @escaping (Bool, Error?) -> Void) {
        self.serviceEndpoint = "deviceservices/awmdmsdk/v1/platform/\(self.config.deviceType)/uid/\(self.config.deviceId)/requery/\(type.rawValue)"

        guard self.endpointURL != nil else {
            completion(false, AWError.SDK.Service.General.invalidHTTPURL("\(self.hostUrlString), \(self.serviceEndpoint)"))
            return
        }

        self.GET{ (rsp: CTLJSONObject?, error: NSError?) in
            if let error = error {
                completion(false, error)
                return
            }

            guard let jsonObject = rsp?.JSON, let dictionary = jsonObject as? [String: AnyObject] else {
                completion(false, AWError.SDK.Service.General.unexpectedResponse.error)
                return
            }

            guard let status = dictionary["status"] ??  dictionary["Status"] else {
                completion(false, AWError.SDK.Service.General.unexpectedResponse.error)
                return
            }

            guard let value = status as? Int else {
                completion(false, AWError.SDK.Service.General.unexpectedResponse.error)
                return
            }

            if value == 0 {
                //Success status will be returned as Zero(0) from console
                completion(true, nil)
            } else if value == 1 {
                //Failure status will be returned as One(1) from console
                completion(false, nil)
            } else {
                //Unknown or invalud status anythign else
                completion(false, AWError.SDK.Service.General.unexpectedResponse.error)
            }
        }
    }
}
