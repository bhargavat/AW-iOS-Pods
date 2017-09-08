//
//  CTLTask.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


open class CTLTask <T>: Task<T> {
    /// The fetcher associated with the task if any.
    open var fetcher: CTLSessionFetcher? = nil
    public override init() {
        super.init()
    }
    deinit {
        completedValue = nil
        completedError = nil
        self.fetcher = nil
        callbacks.removeAll()
        errbacks.removeAll()
        finallys.removeAll()
    }
}
