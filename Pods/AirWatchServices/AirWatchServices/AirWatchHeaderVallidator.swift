//
//  AirWatchHeaderVallidator.swift
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


protocol AbstractAirWatchResponseValidator: CTLResponseValidationProtocol { }

extension AbstractAirWatchResponseValidator {
    
    func validateResponse(_ response: HTTPURLResponse?, responseData: Data?, completion:(NSError?) -> Void) -> Void {
        var error: NSError? = nil
        if response?.allHeaderFields[AuthenticationConstants.kAWAuthResponseHeaderAWVersionKey] == nil {
            var userInfo:[AnyHashable: Any]  = [NSLocalizedDescriptionKey: ""]
            if let data = responseData {
                userInfo["responseData"] = data
            }
            userInfo["response"] = response
            error = NSError(domain: "AWServices.Response.Validation", code: 0xe1101, userInfo: userInfo);
        }

        completion(error)
    }
}

internal struct AirWatchHeaderValidator: AbstractAirWatchResponseValidator {}
