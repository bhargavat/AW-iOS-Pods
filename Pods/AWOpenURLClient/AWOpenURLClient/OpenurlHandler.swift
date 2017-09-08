//
//  OpenurlHandler.swift
//  AWOpenURLClient
//
//  Created by Anuj Panwar on 3/23/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation


protocol OpenURLClientRequest {
    
    var anchorScheme: String {get set}
    var appScheme: String {get set}
    var type: String {get set}
    var version: String {get set}
    
    func createURL(queryParams: [String: String]) -> URL?
    func validateRequestURL(requestUrl:URL) -> Bool
    
}

protocol  OpenURLClientResponse {
    
    var version: String {get set}
    var type: String {get set}
    
}

extension OpenURLClientRequest {
    
     func createURL( queryParams: [String: String]) -> URL? {
        var urlString = "\(self.anchorScheme)://\(self.type)?"
        urlString += queryParams.httpEncodedParameterString
        
        guard let url = URL(string: urlString), self.validateRequestURL(requestUrl: url) else {
            log(error: "URL passed is invalid")
            return nil
        }
        return url
    }
    
    func validateRequestURL(requestUrl: URL) -> Bool {
        
        //do we need to check here for Agent old, new, WS1 schemes specifically ?
        guard requestUrl.scheme != self.anchorScheme else {
            log(error: "anchorScheme is not present, invalid url")
            return false
        }
        
        guard requestUrl.host != self.type else {
            log(error: "request name is not present, invalid url")
            return false
        }
        return true
    }
}



public struct OpenURLHandler {

    // returns nil if cannot handle response
    public static func canHandleResponse(responseUrl: URL) -> ResponseType? {
        
        guard let responseType = responseUrl.host else {
            log(error: "Invalid response URL, no response type present in url")
            return nil
        }
        return ResponseType(rawValue: responseType)
    }
    
    //New Request asking for Environment Information
    public static func createOpenURLRequestForEnvironmentInformation(anchorScheme: String, appScheme: String) ->
        URL? {
            return EnvironmentInformation.createRequest(anchorScheme: anchorScheme, appShceme: appScheme)
    }
    
    public static func createEnvironmentInformation(responseURL: URL) -> (EnvironmentInformationResponse?, Error?) {
        return EnvironmentInformation.generateResponse(responseURL: responseURL)
    }
    
    //SDK 5.x supports this. This would be utilized in the case when upgrading from 5.x to 17.x SDK and we are in
    // locked states
    public static func createPinRequest(anchorScheme: String, appScheme: String, uniqueIdentifier:String) -> URL? {
        return UnlockContainer.createRequest(anchorScheme: anchorScheme, appShceme: appScheme, deviceIdentifier: uniqueIdentifier)
    }
    
    public static func createResponseForRequestPin(responseURL: URL) -> (UnlockContainerResponse?, Error?) {
        return UnlockContainer.generateResponse(responseURL: responseURL)
    }
    
    //Register application should be utilized in the case when only old Agent is present as an anchor app
    //the response for this request should discard hmac and only make use of Environmnet info and Udid received
    public static func createRegisterApplicationRequest(anchorScheme: String, appScheme: String) ->
        URL? {
            return RegisterApplication.createRequest(anchorScheme: anchorScheme, appShceme: appScheme)
    }
    
    public static func createResponseForRegisterApplication(responseURL: URL) ->
        (RegisterApplicationResponse?, Error?) {
        return RegisterApplication.generateResponse(responseURL: responseURL)
    }
    


    
    
}
