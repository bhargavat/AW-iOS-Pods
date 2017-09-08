//
//  UnlockContainer.swift
//  AWOpenURLClient
//
//  Created by Anuj Panwar on 3/31/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation


public struct UnlockContainerResponse {
    
    public let decryptionPin: String
    public let lastAuthenticationTimeStamp: Date
    public let validityPeriod: TimeInterval
    
}

struct UnlockContainer {
    
    static let requestType  = "requestPin"
    static let responseType = "requestPinResponse"
    
    static func createRequest(anchorScheme: String, appShceme: String, deviceIdentifier: String) -> URL? {
        
        guard let bundleId = Bundle.main.bundleIdentifier else {
            log(error: "No bundleId. Cannot create UnlockContainer request")
            return nil
        }
        
        let uniqueId = "AWOpenURLClient.\(bundleId)"
        guard let cryptoAgent = CryptoHelper(identifier: uniqueId),
            let encryptionKey = cryptoAgent.encryptionKey
            else {
                log(error: "failed to create encryption key. Cannot create UnlockContainer Request")
                return nil
        }
        
        RegisterApplication.securityHelper = cryptoAgent
        let request = Request(anchorScheme: anchorScheme, appScheme: appShceme,
                              type: UnlockContainer.requestType,
                              version: "1.0", encryptionKey: encryptionKey,
                              containerId: deviceIdentifier)
                              
        
        //create key value pairs for the request
        var params = [String: String]()
        params[SDK5xRequestKeys.EncryptionKey.rawValue]      = request.encryptionKey
        params[SDK5xRequestKeys.ContainerId.rawValue]        = request.containerId
        params[OpenURLConst.Keys.AppScheme.rawValue]         = request.appScheme
        guard let requestURL = request.createURL(queryParams: params) else {
            log(error: "error creating request URL for UnlockContainer from the parameters")
            return nil
        }
        return requestURL
    }
    
    static func generateResponse(responseURL: URL) -> (UnlockContainerResponse?, Error?) {
        
        guard let cryptHelper = RegisterApplication.securityHelper else {
            log(error: "unable to process URL")
            return (nil, nil)
        }
        guard let response = Response(responseURL: responseURL, cryptoHelper: cryptHelper) else {
            var returnError: Error? = nil
            if let responseError = Response.error(responseURL: responseURL) {
                returnError = responseError
            }
            return (nil, returnError)
        }
        return (response.successResponse, nil)
    }

    
    struct Request: OpenURLClientRequest {
        
        var anchorScheme: String
        var appScheme: String
        var type: String
        var version: String
        
        internal var encryptionKey: String
        internal var containerId: String
        
        func createURL( queryParams: [String: String]) -> URL? {
            var urlString = "\(self.anchorScheme)://\(self.type)?"
            urlString += queryParams.httpEncodedParameterStringWithSDK5xCompatible
            guard let url = URL(string: urlString), self.validateRequestURL(requestUrl: url) else {
                log(error: "URL passed is invalid")
                return nil
            }
            return url
        }
        
        func validateRequestURL(requestUrl: URL) -> Bool {
            //do we need to check here for Agent old, new, WS1 schemes specifically ?
            guard let scheme = requestUrl.scheme, scheme == self.anchorScheme else {
                log(error: "anchorScheme is not present, not a valid url")
                return false
            }
            
            guard let host = requestUrl.host, host ==  RequestType.RegisterApplication.rawValue else {
                log(error: "request name is not present, not a valid url")
                return false
            }
            
            guard requestUrl.queryItem(key: OpenURLConst.Keys.AppScheme.rawValue) == self.appScheme else {
                log(error: "callback scheme not added, not a valid url")
                return false
            }
            
            guard requestUrl.queryItem(key: SDK5xRequestKeys.EncryptionKey.rawValue) == self.encryptionKey,
                requestUrl.queryItem(key: SDK5xRequestKeys.ContainerId.rawValue) == self.containerId
                else {
                    log(error: "missing request information, not a valid url")
                    return false
            }
            return true
        }
    }
    
    struct Response: OpenURLClientResponse {
        
        var version: String
        var type: String
        var successResponse: UnlockContainerResponse
        var cryptoAgent: CryptoHelper
        
        init?(responseURL: URL, cryptoHelper: CryptoHelper) {
            
            guard let responseType = responseURL.host,
                responseType == UnlockContainer.responseType,
                let encryptedPaylod = responseURL.queryItem(key: SDK5xResponseKeys.EncryptedPayload.rawValue)
                else {
                    log(error: "incorrect URL format, cannot create a Response")
                    return nil
            }
            
            guard let decryptedQuery = cryptoHelper.decryptPayload(encryptedPayload: encryptedPaylod),
                let pin =  decryptedQuery.queryItemFromQuery(key:SDK5xResponseKeys.UnlockPin.rawValue),
                let timeSince1970Value = decryptedQuery.queryItemFromQuery(key:SDK5xResponseKeys.LastAuthenticationTime.rawValue),
                let validityPeriodValue = decryptedQuery.queryItemFromQuery(key:SDK5xResponseKeys.ValidityPeriod.rawValue),
                let timeSince1970 = Double(timeSince1970Value),
                let validityPeriod = TimeInterval(validityPeriodValue)
                else {
                    log(error: "error decrypting contents of payload")
                    return nil
            }
            
            let lastAuthenticationDate = Date(timeIntervalSince1970: timeSince1970)
            self.cryptoAgent = cryptoHelper
            self.version = "1.0"
            self.type = responseType
            self.successResponse = UnlockContainerResponse(decryptionPin: pin, lastAuthenticationTimeStamp: lastAuthenticationDate, validityPeriod: validityPeriod)
        }
        
        static func error(responseURL: URL) -> Error? {
            guard let responseType = responseURL.host,
                responseType == UnlockContainer.responseType,
                let errorCodeString = responseURL.queryItem(key: SDK5xResponseKeys.ErrorCode.rawValue) else {
                    return nil
            }
            return OpenURLError.ErrorResponse(errorCodeString)
        }
        
    }
}
