//
//  UnEnrollmentEndpoint.swift
//  AirWatchServices
//
//  Created by Iury Bessa on 7/7/16.
//  Copyright © 2016 VMWare, Inc. All rights reserved.
//

import Foundation
import AWNetwork

internal class UnEnrollmentEndpoint: DeviceServicesEndpoint {
    var fetcher: CTLSessionFetcher?
    
    
    required public init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        
        self.serviceEndpoint = "/deviceservices/awmdmsdk/v1/platform/2/uid/\(config.deviceId)/command/unenroll"
    }
    
    /**
     For this function to be called correctly, the user must be enrolled using HMAC and the authorizer object used to initialize UnEnrollmentEndpoint object best suited for this is one using HMAC(HMACAuthentication)
     */
    public func deviceUnenrollmentForAuthenticatedUser(completion completionHandler: @escaping (_ statusForDidUnEnroll: Bool) -> () ){
        //NOTE: must send logs before calling this function in AWController or a bug will be raised.
        self.GET { (data: Data?, error: NSError?) in
            
            if error == nil {
                // if there is no error, then everything was successful
                completionHandler(true)
                return
            }
            
            log(error: "Unknown error occured while unenrolling the device. Unable to report to server unenrollment request using HMAC")
            completionHandler(false)
        }
    }

    /**
     If a user has not been authenticated using HMAC, this function attempts to unenroll by using an authorizer object used to initialize UnEnrollmentEndpoint which uses secure channel(SecureChannelAuthenticator)
     */
    public func deviceUnenrollmentForNonAuthenticatedUser(completion completionHandler: @escaping (_ statusForDidUnEnroll: Bool) -> () ){
        let body = ["messageType":"awmdmsdk", "action":"unenroll"]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: JSONSerialization.WritingOptions.prettyPrinted)
        
        self.POST(bodyData, completionHandler: { (rsp: Data?, error: NSError?) in
            
            if error == nil {
                // if there is no error, then everything was successful
                completionHandler(true)
                return
            }
            
            log(error: "Unknown error occured while unenrolling the device. Unable to report to server unenrollment request using secure channel")
            completionHandler(false)
        })
    }
    
    override public func requestForURL(_ url: URL,
                                         ETag: String?,
                                         httpMethod: String,
                                         additionalHeaders: [String: String]?) -> NSMutableURLRequest? {
        let request = super.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: additionalHeaders)
        
        // When using secure channel, the requestType must be set as 'message'
        // Also other components of secure channel the request must also be POST, content type application/json, and must have body data of string {\"messageType\" : \"awmdmsdk\", \"action\" : \"unenroll\"} encoded in UTF8
        // All of these properties are set by using the helper function POST and the SecureChannel authorizer
        request?.requestType = "message"
        
        return request
    }
}
