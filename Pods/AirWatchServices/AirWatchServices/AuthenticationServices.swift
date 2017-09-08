//
//  AirWatchServices.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWError

public class AuthenticationServices {

    internal static var RemoteAuthentication = UserRemoteAuthentication.self

    public static func validateAuthenticationServicesAvailability(_ hostname: String, completion:@escaping (_ validatedHostname: String?, _ error: NSError?) -> Void) {
        let urlsToValidate = HostnameSanitizer.getSanitizedHTTPUrls(hostname)
        AuthenticationServices.validateURLlist(hostname, hostURLStringsList: urlsToValidate, completion: completion)
    }

}


extension AuthenticationServices {

    fileprivate static func validateURLlist(_ hostname: String, hostURLStringsList: [String], completion:@escaping (_ validatedHostname: String?, _ error: NSError?) -> Void) -> Void {
        var urlsToValidate = hostURLStringsList
        if urlsToValidate.count == 0 {
            completion(nil, AWError.SDK.Service.Authentication.hostnameValidationFailed(hostname).error)
            return
        }

        let validatingURLString = urlsToValidate.removeFirst()
        let _ = try? RemoteAuthentication.retrieveConsoleVersion(validatingURLString) { (consoleVersion, urlString, error) in
            if consoleVersion != nil {
                completion(urlString, nil)
                return
            } else {
                AuthenticationServices.validateURLlist(hostname, hostURLStringsList: urlsToValidate, completion: completion)
            }
        }

    }
}
