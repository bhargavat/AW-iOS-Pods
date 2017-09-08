//
//  AWController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//



import Foundation

internal extension AWController {

    internal func HMACRefreshNotification(_ notification: Notification) -> Void {
        
        log(info: "HMAC changed enqueing ProxyPolicyEnforcer to shared queue")
        let operation = ProxyPolicyEnforcer.init(sdkController: self, presenter: self.presenter, dataStore: self.context)
        operation.forceRestart = true
        SDKOperationQueue.sharedQueue.addOperation(operation)

    }
}



