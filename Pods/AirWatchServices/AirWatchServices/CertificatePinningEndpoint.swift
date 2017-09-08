//
//  CertificatePinningEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork


internal class CertificatePinningEndpoint: DeviceServicesEndpoint {
    
    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = "deviceservices/CertificatePinningEndpoint"
    }
    
    public func fetchPublicKeysToPin(_ completionHandler: @escaping (_ pinKeyResponse: [String: [String]]?, _ error: NSError?) -> Void) {
        
        guard let endpointURL = self.endpointURL else {
            completionHandler(nil, NSError(domain: "AirWatchServices.CertificatePinningEndpoint", code: 1, userInfo: nil))
            return
        }
        
        let queryHelper = CTLQuery()
        queryHelper.addtionalHTTPHeaders = ["deviceType":self.config.deviceType, "aw-auth-device-uid":self.config.deviceId]
        _ = self.fetchURL(endpointURL, dataToPost: nil, ETag: nil, httpMethod: "GET", mayAuthorize: true, executingQuery: queryHelper) { (rsp:CTLJSONObject?, error: NSError?) in
            if let publicKeyResponse = rsp?.JSON  as? [String: [String]] {
                completionHandler(publicKeyResponse, nil)
                return
            }
            
            if let error = error {
                log(error: "Fetch public Keys to pin received error: \(error)")
                completionHandler(nil, error)
            } else {
                log(error: "Fetch public keys to pin failed without error")
                completionHandler(nil, NSError(domain: "AirWatchServices.CertificatePinningEndpoint", code: 2, userInfo: nil))
            }
        }
    }
}
