//
//  SupportInformation.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWNetwork
import AWError
import Foundation

public protocol SupportInformation {
    var email: String? { get }
    var telephoneNumber: String? { get }
    var errorMessage: String? { get }
}

struct SupportInformationStruct: SupportInformation {
    var email: String?
    var telephoneNumber: String?
    var errorMessage: String?
}

public typealias SupportInformationFetchCompletion = (_ supportInfo: SupportInformation?,_ error: Error?) -> Void

internal class SupportInformationEndpoint: DeviceServicesEndpoint {
    let kSupportInformationEndpoint = "/deviceservices/DeviceInfo.svc/GetSupportInfo"
    
    required public init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        
        self.serviceEndpoint = kSupportInformationEndpoint
    }
    
    public func fetchSupportInformation(completion: @escaping SupportInformationFetchCompletion) -> Void {
        let body = ["request":["DeviceType":self.config.deviceType,"Uid": self.config.deviceId]]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: JSONSerialization.WritingOptions.prettyPrinted)
        
        self.POST(bodyData, completionHandler: { (data: Data?, error: NSError?) in
            if let error = error {
                completion(nil, AWError.SDK.CoreNetwork.CTL.createRequestFailure(error.localizedDescription))
                return
            }
            
            /**
             The returned data from console is JSON and the form of the JSON is displayed here
             {
                "d": {
                    "Email":"noreply@company.com",
                    "ErrorMessage":"",
                    "HasErrors":false,
                    "Telephone":"888-888-8888"
                }
             }
             */
            // Unwrap the data, json and the d dictionary if it exists
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? Dictionary<String, Any>,
                let d_entries = json?["d"] as? Dictionary<String, Any>,
                let hasErrors = d_entries["HasErrors"] as? Bool else {
                    // Some value is missing or different from what is expected
                    completion(nil, AWError.SDK.General.jsonDeserializationFailed.error)
                    return
            }
            
            var supportInformation = SupportInformationStruct()
            supportInformation.email = d_entries["Email"] as? String
            supportInformation.telephoneNumber = d_entries["Telephone"] as? String
            supportInformation.errorMessage = d_entries["ErrorMessage"] as? String
            
            // When the server has an error message (usually if accessing a secure channel endpoint unsecurily), return an error object
            var error: Error? = nil
            if hasErrors == true {
                error = AWError.SDK.General.configurationValuesUnavailable.error
            }
            completion(supportInformation, error)
        })
    }
    
    override public func requestForURL(_ url: URL,
                                       ETag: String?,
                                       httpMethod: String,
                                       additionalHeaders: [String: String]?) -> NSMutableURLRequest? {
        let request = super.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: additionalHeaders)
        
        // When commmunicating with SecureChannel, a Envelope name is needed. The Envelope's content is data wrapped in base64 which encapsulates the endpoint URL and http body which was passed to POST in fetchSupportInformation
        request?.requestType = "supportInfo"
        
        return request
    }
}
