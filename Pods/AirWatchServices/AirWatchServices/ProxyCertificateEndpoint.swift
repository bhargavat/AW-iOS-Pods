//
//  ProxyCertificateEndpoint.swift
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


public protocol ProxyCertificateInfo {

    var certificateData: Data { get }

}


internal struct ProxyCertificate: ProxyCertificateInfo {
    var certificateData: Data
}


public typealias ProxyCertificateCompletionHandler = (_ certificate: ProxyCertificateInfo?, _ error: NSError?) -> Void

internal class ProxyCertificateEndpoint: DeviceServicesEndpoint {
    let kProxyCertficateEndpoint = AuthenticationConstants.kAWAuthEndpoint

    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = kProxyCertficateEndpoint
    }
    
    public func fetchProxyCertificates(_ completionHandler: @escaping ProxyCertificateCompletionHandler) -> Void {
        guard self.endpointURL != nil else {
            completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL("\(hostUrlString), \(serviceEndpoint)").error)
            return
        }

        do {
            let jsonData = try jsonPayload()
            guard let endpointURL = endpointURL else {
                completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL("nil").error)
                return
            }

            self.POST(endpointURL, data: jsonData) { (rsp: CTLJSONObject?, error: NSError?) in
                if let err = error {
                    completionHandler(nil, err)
                } else {
                    if let cert = rsp?.JSON?["AWAuthenticationCertificate"] {
                        if let certStr = cert as? String,
                           let certData = Data(base64Encoded: certStr, options: Data.Base64DecodingOptions(rawValue: 0)) {
                            let certInfo = ProxyCertificate(certificateData: certData)
                            completionHandler(certInfo, nil)
                        } else {
                            completionHandler(nil, AWError.SDK.Service.General.unexpectedResponse.error)
                        }
                    } else {
                        completionHandler(nil, AWError.SDK.Service.General.invalidJSONResponse.error)
                    }
                }
            }
        } catch let err {
            completionHandler(nil, (err as! AWSDKErrorType).error)
        }
    }

    fileprivate func jsonPayload() throws -> Data {
        var dict: [String: String] = [String: String]()
        dict["Username"] = ""
        dict["Password"] = ""
        dict["ActivationCode"] = ""
        dict["Udid"] = self.config.deviceId
        dict["DeviceType"] = self.config.deviceType
        dict["BundleId"] = self.config.bundleId
        dict["RequestingApp"] = ""
        dict["AuthenticationType"] = "4" /// Cert Request
        dict["AuthenticationGroup"] = self.config.bundleId

        return try JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: 0))
    }
}
