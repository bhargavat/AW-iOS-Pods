//
//  RegisterApplication.swift
//  AWOpenURLClient
//
//  Created by Anuj Panwar on 3/30/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation


public struct RegisterApplicationResponse {
    /// serverURL to use when communicating with the AirWatch endpoint
    public let serverURL: String
    /// optional as Agent does not right now give group id
    public let orgGroup: String?
    /// AirWatch identifier to use when communicating with the AirWatch endpoint
    public let airwatchID: String
}

struct RegisterApplication {
    
    //TODO:: this var can be removed when we no longer support AirWatch Container app
    static var udidToRegister: String? = nil
    static var securityHelper: CryptoHelper?
    static func createRequest(anchorScheme: String, appShceme: String) -> URL? {
        
        guard let bundleId = Bundle.main.bundleIdentifier else {
            log(error: "No bundleId. Cannot create RegisterApplication Request")
            return nil
        }
        
        let uniqueId = "AWOpenURLClient.\(bundleId)"
        guard let cryptoAgent = CryptoHelper(identifier: uniqueId),
        let encryptionKey = cryptoAgent.encryptionKey
        else {
             log(error: "failed to create encryption key. Cannot create RegisterApplication Request")
            return nil
        }
        
        RegisterApplication.securityHelper = cryptoAgent
        guard let generatedUDID = UUID().uuidString.data(using: .utf8)?.sha1 else {
            log(error: "Unable to generate a device ID for the third-party app")
            return nil
        }
        
        RegisterApplication.udidToRegister = generatedUDID.hexString
        let request = Request(anchorScheme: anchorScheme, appScheme: appShceme,
                              type: RequestType.RegisterApplication.rawValue,
                              version: "1.0", bundleVersion: "1.0", bundleShortVersion: "1.0",
                              encryptionKey: encryptionKey, encryptionVersion: CryptoHelper.cryptVersion,
                              containerId: generatedUDID.hexString,
                              bundleID: bundleId)
        
        //create key value pairs for the request
        var params = [String: String]()
        params[SDK5xRequestKeys.BundleID.rawValue]           = request.bundleID
        params[SDK5xRequestKeys.BundleVersion.rawValue]      = request.bundleVersion
        params[SDK5xRequestKeys.BundleVersionShort.rawValue] = request.bundleShortVersion
        params[SDK5xRequestKeys.EncryptionKey.rawValue]      = request.encryptionKey
        params[SDK5xRequestKeys.EncryptionVersion.rawValue]  = request.encryptionVersion
        params[SDK5xRequestKeys.ContainerId.rawValue]        = request.containerId
        params[OpenURLConst.Keys.AppScheme.rawValue]         = request.appScheme
        
        guard let requestURL = request.createURL(queryParams: params) else {
            log(error: "error creating request URL for RegisterApplication from the parameters")
            return nil
        }
        return requestURL
    }
    
    static func generateResponse(responseURL: URL) -> (RegisterApplicationResponse?, Error?) {
        
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
        
        //specific to 5.x SDK
        var bundleVersion: String
        var bundleShortVersion: String
        var encryptionKey: String
        var encryptionVersion: String
        var containerId: String
        var bundleID: String
        
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
            
            guard requestUrl.queryItem(key: SDK5xRequestKeys.BundleID.rawValue) == self.bundleID,
            requestUrl.queryItem(key: SDK5xRequestKeys.BundleVersion.rawValue) == self.bundleVersion,
            requestUrl.queryItem(key: SDK5xRequestKeys.BundleVersionShort.rawValue) == self.bundleShortVersion,
            requestUrl.queryItem(key: SDK5xRequestKeys.EncryptionKey.rawValue) == self.encryptionKey,
            requestUrl.queryItem(key: SDK5xRequestKeys.EncryptionVersion.rawValue) == self.encryptionVersion,
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
        var successResponse: RegisterApplicationResponse
        var cryptoAgent: CryptoHelper
        
        init?(responseURL: URL, cryptoHelper: CryptoHelper) {
            
            //check for error as 5x sdk (with Agent) returns a valid response url with serverurl in case when the app is not whitelisted
            if  responseURL.queryItem(key: SDK5xResponseKeys.ErrorCode.rawValue) != nil {
                return nil
            }
            
            guard let responseType = responseURL.host,
                responseType == ResponseType.RegisterApplication.rawValue,
                let encryptedPaylod = responseURL.queryItem(key: SDK5xResponseKeys.EncryptedPayload.rawValue),
                let serverURLString = responseURL.queryItem(key: OpenURLConst.Keys.ServerURL.rawValue)
                else {
                    log(error: "incorrect URL format, cannot create a Response")
                    return nil
            }
            
            guard let url = URL(string: serverURLString), let serverURLScheme = url.scheme,
            let serverURLHost = url.host
            else {
                log(error: "incorrect server url received")
                return nil
            }
            
            let serverURL =  "\(serverURLScheme)://\(serverURLHost)"
            guard let decryptedQuery = cryptoHelper.decryptPayload(encryptedPayload: encryptedPaylod)
                else {
                    log(error: "error decrypting contents of payload")
                    return nil
            }

            var deviceIdentifier: String? = nil
            if let airwatchIdFromResponse =  decryptedQuery.queryItemFromQuery(key:SDK5xResponseKeys.Awidentifier.rawValue) {
                deviceIdentifier = airwatchIdFromResponse
            }else {
                //TODO:: this code can be removed when we no longer support AirWatch Container app
                deviceIdentifier = RegisterApplication.udidToRegister
                log(error: "device identifier not found in response. Assigning the one sent in request. Response must be received from container app")
            }
            
            guard let airwatchID = deviceIdentifier else {
                log(error: "device identifier cannot be passed for RegsiterApplication response. Should not happen!!")
                return nil
            }
            
            guard airwatchID.isValidHexadecimalString, airwatchID.characters.count == 40 else {
                log(error: "invalid udid: \(airwatchID) retrieved from response")
                return nil
            }
            
            //groupId is not always returned from 5.x SDK
            let groupId = decryptedQuery.queryItemFromQuery(key: OpenURLConst.Keys.OrgGroupId.rawValue)
            self.cryptoAgent = cryptoHelper
            self.version = "1.0"
            self.type = responseType
            self.successResponse = RegisterApplicationResponse(serverURL: serverURL, orgGroup: groupId, airwatchID: airwatchID)
        }
        
        static func error(responseURL: URL) -> Error? {
            guard let responseType = responseURL.host,
            responseType == ResponseType.RegisterApplication.rawValue,
                let errorCodeString = responseURL.queryItem(key: SDK5xResponseKeys.ErrorCode.rawValue) else {
                    return nil
            }
            return OpenURLError.ErrorResponse(errorCodeString)
        }
        
    }
}

extension Dictionary
where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {
    
    //SDK 5.x do not expected a encoded string
    internal var httpEncodedParameterStringWithSDK5xCompatible: String {
        let parameterArray = self.map {
            (key, value) -> String in
            return "\(key)=\(value)"
            }.sorted()
        
        return parameterArray.joined(separator: "&")
    }
    
}

extension String {
    //extract query item, expects query part of the url
    internal func queryItemFromQuery(key: String) -> String? {
        guard let encodedQuery = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let url =  URL(string: "sampleScheme://sampleHost?\(encodedQuery)"),
        let item = url.queryItem(key: key)
        else {
            return self.extractItemByParsingComponentsFromQuery(key: key)
        }
        return item
    }
    
    func extractItemByParsingComponentsFromQuery(key: String) -> String? {
        let components = self.components(separatedBy: "&")
        var dictionary = [String:String]()
        for pairs in components {
            let pair = pairs.components(separatedBy: "=")
            if pair.count == 2 {
                dictionary[pair[0]] = pair[1]
            }
        }
        if let value = dictionary[key] {
            return value
        }
        log(error: "error parsing query item: \(key)")
        return nil

    }
}

enum SDK5xRequestKeys: String {
    case BundleID               = "AWApplicationIdentifier"
    case BundleVersion          = "bversion"
    case BundleVersionShort     = "bsversion"
    case ContainerId            = "cid"
    case EncryptionKey          = "enckey"
    case EncryptionVersion      = "crvs"
}

enum SDK5xResponseKeys: String {
    case EncryptedPayload       = "encpld"
    case Awidentifier           = "udid"
    case ErrorCode              = "erc"
    case LastAuthenticationTime = "lauthtime"
    case ValidityPeriod         = "period"
    case UnlockPin              = "pin"
}






