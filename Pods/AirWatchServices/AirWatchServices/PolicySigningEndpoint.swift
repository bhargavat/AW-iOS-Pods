//
//  PolicySigningEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork
import AWCrypto
import AWError

internal class PolicySigningEndpoint: DeviceServicesEndpoint {
    
    let containsCertKey = "ContainsCertificate"
    let contentTypeKey = "X509ContentType"
    let certStringEncodingKey = "CertificateStringEncoding"
    let certKey = "Certificate"
    let certChainKey = "X509Chain"
    
    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        /// Validator is not used for this request since it is a request to get the certificate used by the validator to validate responses.
        super.init(config: config, authorizer: authorizer, validator: nil)
        self.serviceEndpoint = "deviceservices/policysigningcertificate?requestType=x5c"
    }
    
    public func fetchPolicySigningCertificate(_ completionHandler: @escaping (_ certificateResponse: [AWCrypto.Certificate]?, _ error: NSError?) -> Void) {
        
        guard let endpointURL = self.endpointURL else { /// This should never happen.
            completionHandler(nil, AWError.SDK.CoreNetwork.CTL.invalidURL.error)
            return
        }
        
        _ = self.fetchURL(endpointURL, dataToPost: nil, ETag: nil, httpMethod: "GET", mayAuthorize: true, executingQuery: nil) { (rsp:CTLJSONObject?, error: NSError?) in
            
            if let jsonResponse = rsp?.JSON  as? [String: AnyObject] {
                guard let isCertPresent = jsonResponse[self.containsCertKey] as? Bool , isCertPresent == true else {
                    completionHandler(nil, nil)
                    return
                }
                // TODO: Change this to handle an Array of cert strings that are encoded the same way.
                guard let certStringEncoding = jsonResponse[self.certStringEncodingKey] as? String, let contentType = jsonResponse[self.contentTypeKey] as? String else {
                    completionHandler(nil, AWError.SDK.Service.Endpoint.PolicySigning.failedToFetchCertificate.error)
                    return
                }
                
                var encodedCertArray: [String] = []
                
                if let certArray = jsonResponse[self.certChainKey] as? [String] {
                    encodedCertArray.append(contentsOf: certArray)
                }
                
                if let certString = jsonResponse[self.certKey] as? String , encodedCertArray.count == 0 {
                    encodedCertArray.append(certString)
                }
                
                guard encodedCertArray.count > 0 else {
                    completionHandler(nil, AWError.SDK.Service.Endpoint.PolicySigning.failedToFetchCertificate.error)
                    return
                }
                
                var decodedCertArray: [Data] = []
                switch certStringEncoding.lowercased() {
                case "base64":
                        for encodedCertString in encodedCertArray {
                            let decodedCertData = Data(base64Encoded: encodedCertString, options: Data.Base64DecodingOptions(rawValue: 0))
                            if let decodedCertData = decodedCertData {
                                decodedCertArray.append(decodedCertData)
                            }
                        }
                        break
                    default:
                        // Leave the decodedCertArray as empty, since we don't know what encoding was used to transport it over network.
                        log(warning: "Detected unsupported string encoding for NIAP Policy Signing Cert.")
                        break
                }
                
                guard decodedCertArray.count > 0 else {
                    completionHandler(nil, AWError.SDK.Service.Endpoint.PolicySigning.failedToDecodeCertificateData(GivenEncoding: self.certStringEncodingKey).error)
                    return
                }
                
                var serverCertificateArray: [AWCrypto.Certificate] = []
                switch contentType.lowercased() {
                    case "cert":
                        for certificateData in decodedCertArray {
                            if let serverCertificate = try? AWCrypto.Certificate(certificateData: certificateData, format: CertificateFormat.der) {
                                serverCertificateArray.append(serverCertificate)
                            }
                        }
                        guard CertificateTrust.validateTrust(serverCertificateArray) else {
                            log(error: "Unable to Trust retrieved certificate.")
                            completionHandler(nil, AWError.SDK.Service.Endpoint.PolicySigning.general.error)
                            return
                        }
                        break
                    
                    case "pfx":
                        log(error: "PFX Certificate format unsupported at this time.")
                        break
                    
                    default:
                        log(error: "Received unsupported NIAP Signing Certificate format.")
                        break
                }
                
                if serverCertificateArray.count > 0 {
                    completionHandler(serverCertificateArray, nil)
                } else {
                    completionHandler(nil, AWError.SDK.Service.Endpoint.PolicySigning.failedToCreateCertificate(GivenType: self.contentTypeKey).error)
                }
                
                return
            }
            
            if let error = error {
                log(error: "Fetch policy signing certificate received error: \(error)")
                completionHandler(nil, error)
            } else {
                log(error: "Fetch policy signing certificate failed without error")
                if let urlResponse = rsp?.properties?[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse {
                    completionHandler(nil, AWError.SDK.CoreNetwork.CTL.httpStatus(urlResponse.statusCode, "").error)
                } else {
                    completionHandler(nil, AWError.SDK.Service.Endpoint.PolicySigning.general.error)
                }
            }
        }
    }
}
