//
//  TrustServiceDiscoveryEndpoint
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import Alamofire

import AWNetwork
import AWCrypto
import AWError
import AWLog


public class TrustServices {
    var airWatchServerURL: String

    public init(serverURL: String) {
        self.airWatchServerURL = serverURL
    }

    public func retrieveTrustServiceURL(completionHandler: @escaping (_ trustServiceRedirect: String?, _ error: NSError?) -> Void) {
     let endPoint = TrustServiceDiscoveryEndpoint(serverURL: self.airWatchServerURL)
        endPoint.retrieveTrustService(completionHandler: completionHandler)
    }

}

internal class TrustServiceDiscoveryEndpoint {
    internal static var networkManager: SessionManager = SessionManager()
    private let endpointURL: String
    init(serverURL: String) {
        if serverURL.hasPrefix("http") {
            self.endpointURL = "\(serverURL)/deviceservices/trustservicesettings"
        } else {
            self.endpointURL = "https://\(serverURL)/deviceservices/trustservicesettings"
        }
    }

    public func retrieveTrustService(completionHandler: @escaping (_ trustServiceRedirect: String?, _ error: NSError?) -> Void) {
        /// This is used when AutoDiscovery fails to give a list of public Keys.
        guard let retrieveTrustServiceUrl = URL(string: self.endpointURL) else {
            log(error: "Could not create URL to retrieve Trust Service")
            completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL(self.endpointURL).error)
            return
        }

        TrustServiceDiscoveryEndpoint.networkManager.delegate.taskDidReceiveChallengeWithCompletion = {(urlSession: URLSession, urlSessionTask: URLSessionTask, authenticationChallenge: URLAuthenticationChallenge, completion:(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) in
            
            guard authenticationChallenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
                completion(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
                return
            }
            
            guard let serverTrust = authenticationChallenge.protectionSpace.serverTrust else {
                completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
                return
            }
            
            TrustServiceDiscoveryEndpoint.evaluate(serverTrust: serverTrust, completeDisposition: completion)
        }
        
        /**
         SAMPLE REQUEST
         GET https://dsmain.airwatchdev.com/DeviceServices/TrustServiceSettings
         
         SAMPLE RESPONSE
         {
         Uri: "https://dsmain.airwatchdev.com:9001/TrustService"
         }
         */
        
        // TODO: Need to Address possible NIAP Mutual Auth Issues with this implementation.
        log(info: "Retrieving Trust Service Redirect from Console.")
        let networkRequest = TrustServiceDiscoveryEndpoint.networkManager.request(retrieveTrustServiceUrl, method: .get).responseData { (networkResponse) in
            guard networkResponse.result.isSuccess else {
                if let error = networkResponse.result.error {
                    completionHandler(nil, error as NSError?)
                } else {
                    completionHandler(nil, NSError(domain: "PinningCertificateFetchOpeartion", code: 3, userInfo: nil))
                }
                
                return
            }
            
            guard let statusCode = networkResponse.response?.statusCode else {
                completionHandler(nil, NSError(domain: "PinningCertificateFetchOpeartion", code: 4, userInfo: nil))
                return
            }
            
            if statusCode < 200 || statusCode > 299 {
                switch statusCode {
                case 401: completionHandler(nil, AWError.SDK.CoreNetwork.CTL.httpStatus(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode)).error)
                    return
                case 403: completionHandler(nil, AWError.SDK.CoreNetwork.CTL.httpStatus(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode)).error)
                    return
                case 500: completionHandler(nil, AWError.SDK.CoreNetwork.CTL.httpStatus(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode)).error)
                    return
                default: completionHandler(nil, AWError.SDK.CoreNetwork.CTL.httpStatus(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode)).error)
                    return
                }
            }
            
            guard let responseData = networkResponse.result.value else {
                completionHandler(nil, AWError.SDK.General.jsonDeserializationFailed.error)
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.mutableContainers) else {
                completionHandler(nil, AWError.SDK.General.jsonDeserializationFailed.error)
                return
            }
            
            if let jsonDictionary = json as? [String: String] {
                if let trustService = jsonDictionary["Uri"] {
                    completionHandler(trustService, nil)
                    return
                }
            }
            
            completionHandler(nil, AWError.SDK.General.unexpectedJSONType.error)
        }
        
        networkRequest.resume()
    }
    
    internal static func evaluate(serverTrust: SecTrust, completeDisposition:(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        /// Continue without verifying, as don't have any keys to compare against yet.
        guard var trustResultType: SecTrustResultType = SecTrustResultType(rawValue: 0) else {
            completeDisposition(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return
        }
        
        let status = SecTrustEvaluate(serverTrust, &trustResultType)
        
        guard status == noErr && trustResultType == SecTrustResultType.unspecified else {
            completeDisposition(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return
        }
        
        let credentialToUse = URLCredential(trust: serverTrust)
        completeDisposition(URLSession.AuthChallengeDisposition.useCredential, credentialToUse)
    }
}
