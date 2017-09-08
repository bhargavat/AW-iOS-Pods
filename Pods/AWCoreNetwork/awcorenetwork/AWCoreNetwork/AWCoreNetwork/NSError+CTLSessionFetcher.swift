//
//  NSError+CTLSessionFetcher.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
    This NSError extension provides properties that are set by CTLSessionFetcher
    when it signals back a NSError object to its caller site.

    Note that all properties access here is not thread safe or atomic.
 */
public extension NSError {
    public var urlRequest: URLRequest? {
        return self.userInfo[CTLConstants.kCTLDataObjectURLRequest] as? URLRequest
    }

    public var urlResponse: HTTPURLResponse? {
        return self.userInfo[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse
    }

    public var responseData: Data? {
        return self.userInfo[CTLConstants.kCTLDataObjectURLResponseData] as? Data
    }

    public var sessionFetcher: CTLSessionFetcher? {
        return self.userInfo[CTLConstants.kCTLDataObjectFetcher] as? CTLSessionFetcher
    }
}
