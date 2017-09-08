//
//  FetchCertificateEndpoint.swift
//  BeaconEndpoint
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import AWError
import Foundation


public protocol CertificateInfo {

    var certificatateData: Data { get }

    var certificatatePassword: NSString { get }

}


internal struct Certificate: CertificateInfo {
    var certificatateData: Data
    var certificatatePassword: NSString

    init(certData: Data, certPassword: NSString) {
        self.certificatateData = certData
        self.certificatatePassword = certPassword
    }
}


public typealias CertificateFetchCompletionHandler = (_ certificate: CertificateInfo?, _ error: NSError?) -> Void

internal class FetchCertificateEndpoint: DeviceServicesEndpoint {

    let kFetchCertficateEndpoint = "deviceservices/awmdmsdk/v3/certificateservice/requestcertificate/certificateissuer/"

    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = kFetchCertficateEndpoint
    }

    public func fetchCertificates(_ issuer: String,
                                  token: String?,
                                  completionHandler: @escaping CertificateFetchCompletionHandler) -> Void {

        self.serviceEndpoint += issuer.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? issuer
        var queryParameters: [String: String] = [:]
        if let tokenID = token {
            queryParameters["token"] = tokenID
        }

        guard let endpointURL = self.endPointURLWithQueryParameters(queryParameters) else {
            log(error: "Error Fetching Certificate: Invalid URL String")
            completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL("\(self.hostUrlString), \(self.serviceEndpoint)").error)
            return
        }

        guard self.authorizer != nil else {
            log(error: "Error Fetching Certificate: Require valid authorizer")
            completionHandler(nil,
                              AWError.SDK.Service.Endpoint.FetchCertificate.noAuthorizerForCertificateFetching.error)
            return
        }

        self.POST(endpointURL, data: nil) { (rsp: CTLJSONObject?, error: NSError?) in

            guard error == nil else {
                completionHandler(nil, error)
                return
            }

            guard let rsp = rsp, let responseJSON = rsp.JSON else {
                completionHandler(nil, nil)
                return
            }

            guard let responseInfo = responseJSON as? NSDictionary else {
                completionHandler(nil,
                                  AWError.SDK.Service.Endpoint.FetchCertificate.invalidCertificateData.error)
                return
            }

            if let responseType = responseInfo["ResponseType"] as? NSString {
                guard responseType == "Certificate" else {
                    completionHandler(nil,
                                      AWError.SDK.Service.Endpoint.FetchCertificate.unsupportedResponseType(responseType as String).error)
                    return
                }
            }

            if let certStr = responseInfo["Pkcs12"] as? String,
                   let certData = Data(base64Encoded: certStr, options: Data.Base64DecodingOptions(rawValue: 0)) {
                let certPassword = responseInfo["Password"] as? NSString ?? ""
                let certInfo = Certificate(certData: certData, certPassword: certPassword)
                completionHandler(certInfo, nil)
            } else {
                completionHandler(nil,
                                  AWError.SDK.Service.Endpoint.FetchCertificate.invalidCertificateData.error)
            }
        }
    }

}
