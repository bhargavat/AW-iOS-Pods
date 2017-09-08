//
//  NSData+CTLDataObjectProcotol.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import Foundation


/**
 This allows NSData to be passed in as a valid response object  to be returned back in
 completion handler.
 */
extension Data: CTLDataObjectProtocol {
    /**
     NOTE: Returning "Self" requires final class to infer static type of return type, in this case,
     it doesn't allow us to make class extension final, so using below generic function to let
     compiler be able to infer return type.
     */
    fileprivate static func wrapToCTLDataObjectProtocol<T>(_ type: T.Type, data: Data) -> T {
        
        return data as! T //TODO: Is there a better way to do this without force unwrapping
    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> Data {

        var scDataObj: Data = data ?? Data()

        if let fetcher = additionalProperties?[CTLConstants.kCTLDataObjectFetcher] as? CTLSessionFetcher,
            let authorizer = fetcher.authorizer as? SecureChannelAuthorizer,
            let request = additionalProperties?[CTLConstants.kCTLDataObjectURLRequest] as? NSMutableURLRequest,
            let payload = data , payload.count > 0 {
            scDataObj = authorizer.decryptAndVerifySignature(request: request, payload: payload) ?? scDataObj
        }

        return wrapToCTLDataObjectProtocol(self, data: scDataObj)
    }
}
