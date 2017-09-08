//
//  EnvironmentInformation.swift
//  AWOpenURLClient
//
//  Created by Anuj Panwar on 3/24/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation


public struct EnvironmentInformationResponse {
    /// serverURL to use when communicating with the AirWatch endpoint
    public let serverURL: String
    /// organization group to use when communicating with the AirWatch endpoint
    public let orgGroup: String
    /// AirWatch identifier to use when communicating with the AirWatch endpoint
    public let airwatchID: String
}



struct EnvironmentInformation {
    
    static func createRequest(anchorScheme: String, appShceme: String) -> URL? {
        
        let request = Request(anchorScheme: anchorScheme, appScheme: appShceme, type: RequestType.EnvironmentInformation.rawValue,
                              version: OpenURLConst.version)
        //create key value pairs for the request
        var params = [String: String]()
        //version
        params[OpenURLConst.Keys.RequestVersion.rawValue] = OpenURLConst.version
        //apps scheme
        params[OpenURLConst.Keys.AppScheme.rawValue]      = request.appScheme
        guard let requestURL = request.createURL(queryParams: params) else {
            log(error: "error creating a URL from the parameters")
            return nil
        }
        return requestURL
    }
    
    
    static func generateResponse(responseURL: URL) -> (EnvironmentInformationResponse?, Error?) {
        guard let response = Response(responseURL: responseURL) else {
            var returnError: Error? = nil
            if let responseError = Response.error(responseURL: responseURL) {
                returnError = responseError
            }
            return (nil, returnError)
        }
        return (response.successResponse, nil)
    }

    
    struct Request: OpenURLClientRequest {
        
        internal var anchorScheme: String
        internal var appScheme: String
        internal var type: String
        internal var version:String
        
        func validateRequestURL(requestUrl: URL) -> Bool {
            
            //do we need to check here for Agent old, new, WS1 schemes specifically ?
            guard let scheme = requestUrl.scheme, scheme == self.anchorScheme else {
                log(error: "anchorScheme is not present, not a valid url")
                return false
            }
            
            guard let host = requestUrl.host, host ==  RequestType.EnvironmentInformation.rawValue else {
                log(error: "request name is not present, not a valid url")
                return false
            }
            
            guard requestUrl.queryItem(key: OpenURLConst.Keys.AppScheme.rawValue) == self.appScheme else {
                log(error: "callback scheme not added, not a valid url")
                return false
            }
            
            guard requestUrl.queryItem(key: OpenURLConst.Keys.RequestVersion.rawValue) == self.version else {
                log(error: "version not added, not a valid url")
                return false
            }
            return true
        }
    }
    
    struct Response: OpenURLClientResponse {
        
        var version: String
        var type: String
        var successResponse: EnvironmentInformationResponse
        
        init?(responseURL: URL) {

            guard let responseType = responseURL.host,
                responseType == ResponseType.EnvironmentInformation.rawValue,
                let responseVersion = responseURL.queryItem(key: OpenURLConst.Keys.ResponseVersion.rawValue),
                responseVersion == OpenURLConst.version,
                let serverURL = responseURL.queryItem(key: OpenURLConst.Keys.ServerURL.rawValue),
                let groupId = responseURL.queryItem(key: OpenURLConst.Keys.OrgGroupId.rawValue),
                let airwatchId = responseURL.queryItem(key: OpenURLConst.Keys.AirwatchId.rawValue) else {
                    log(error: "incorrect URL format, cannot create a Response")
                    return nil
            }
            
            guard airwatchId.isValidHexadecimalString, airwatchId.characters.count == 40 else {
                log(error: "invalid udid: \(airwatchId) retrieved from response")
                return nil
            }
            version = responseVersion
            type = responseType
            successResponse = EnvironmentInformationResponse(serverURL: serverURL, orgGroup: groupId, airwatchID: airwatchId)
        }
        
        static func error(responseURL: URL) -> Error? {
            
            guard let responseType = responseURL.host,
            responseType == ResponseType.EnvironmentInformation.rawValue,
            //TODO: AWAnchorSDK (WS1) right now does not return version number in case of error
            //let responseVersion = responseURL.queryItem(key: OpenURLConst.Keys.ResponseVersion.rawValue),
            //responseVersion == OpenURLConst.version,
            let errorResponse = responseURL.queryItem(key: OpenURLConst.Keys.ErrorResponse.rawValue) else {
                    return nil
            }
            return OpenURLError.ErrorResponse(errorResponse)
        }
    }
}
