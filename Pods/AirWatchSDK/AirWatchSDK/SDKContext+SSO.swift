//
//  SDKContext.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWServices
import AWStorage

extension SDKContext {

    func evaluatePasscodeCompliance() -> Bool {
        guard let store = self as? ApplicationDataStore else { return false }
        guard  let authenticationPayload = self.SDKProfile?.authenticationPayload else { return true }
        return store.isCurrentPasscodeCompliant(payload: authenticationPayload)
    }
}
