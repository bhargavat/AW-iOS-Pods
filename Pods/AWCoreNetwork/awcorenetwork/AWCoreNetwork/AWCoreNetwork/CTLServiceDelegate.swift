//
//  CTLServiceDelegate.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


public typealias CTLServiceShouldSendRequest = (CTLService, URLRequest) -> Bool
public typealias CTLServiceWillSendRequest = (CTLService, URLRequest) -> Void
public typealias CTLServiceDidSendRequest = (CTLService, URLRequest) -> Void
public typealias CTLServiceShouldFowardRequest = (CTLService, URLRequest) -> URLRequest

/**
 */
public struct CTLServiceDelegate {
    
    public var shouldSendRequest: CTLServiceShouldSendRequest? = nil
    
    public var willSendRequest: CTLServiceWillSendRequest? = nil
    
    public var didSendRequest: CTLServiceDidSendRequest? = nil
    
    /// Allow forward one request to different destiny. The returned request object will be used.
    public var shouldForwardRequest: CTLServiceShouldFowardRequest? = nil
}
