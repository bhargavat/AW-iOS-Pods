//
//  CTLQuery.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


open class CTLQuery : NSObject {
    
    open var urlQueryParameters: Dictionary<String, String>? = nil

    open var addtionalHTTPHeaders: Dictionary<String, String>? = nil

    open var shouldSkipAuthorization: Bool = false

    open var JSON: Dictionary<String, String>? = nil

    open var httpMethod: String = "GET"

    /// The priority for scheduing this query. 0 means default.
    open var priority: UInt = 0

}
