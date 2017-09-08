//
//  OpenURLError.swift
//  AWOpenURLClient
//
//  Created by Anuj Panwar on 3/27/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation

public enum OpenURLError: Error {
    
    case InvalidAnchorScheme
    case MissingAnchorScheme
    case MissingRequestName
    case RequestNameNotSupported
    case MissingCallbackScheme
    case VersionMisMatch
    case MissingVersion
    /// recieved a valid response with error
    case ErrorResponse(String)
    
    //The error string extracted from the URL
    public var errorDescription: String? {
        switch self {
        case .ErrorResponse(let errorString):
            return errorString
         default:
            return nil
        }
    }
}


struct OpenURLConst {
    
    static let version          = "1.0"
    enum Keys: String {
        
        //request
        case RequestVersion     = "awopenurlversionrequest"
        case AppScheme          = "ssocb"
        
        
        //response
        case ResponseVersion    = "awopenurlversionresponse"
        case ErrorResponse      = "errorresponse"
        case OrgGroupId         = "lgrp"
        case ServerURL          = "surl"
        case AirwatchId         = "airwatchid"
    }
}

public enum RequestType: String {
    case EnvironmentInformation     = "requestenvironmentinfo"
    case RegisterApplication        = "appRegister"
}

public enum ResponseType: String {
    case EnvironmentInformation     = "requestenvironmentinforesponse"
    case RegisterApplication        = "appRegisterResponse"
}
