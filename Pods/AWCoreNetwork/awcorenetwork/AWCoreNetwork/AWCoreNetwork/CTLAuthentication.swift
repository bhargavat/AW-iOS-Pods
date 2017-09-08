//
//  CTLAuthentication.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
    Authentication provider could just implement this protocol
 */
public protocol CTLAuthorizationProtocol {

    func authorize(request: NSMutableURLRequest?, on: DispatchQueue?) -> CTLTask<Void>?

    mutating func refreshAuthorization(completion: @escaping (CTLAuthorizationProtocol?, NSError?) -> Void)

    /**
        The fetcher keeper to be used to create a request fetcher with the default properties carried with
        the fetcher keeper itself. It would be set when the protocol implementation is passed into CTLService.
        This property is optional.
     */
    weak var fetcherKeeper: CTLSessionFetcherKeeper? { set get }
}


public extension CTLAuthorizationProtocol {
    /// This makes the property optional
    public weak var fetcherKeeper: CTLSessionFetcherKeeper? {
        set {}
        get { return nil }
    }
}
