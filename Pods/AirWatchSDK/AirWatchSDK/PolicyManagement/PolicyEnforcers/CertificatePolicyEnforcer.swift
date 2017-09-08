//
//  CertificatePolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import Foundation

// TODO: Check what we should do about it.
class CertificatePolicyEnforcer: PolicyEnforcementOperation {
    override var payloadType: String { return SDKCertificatePayload.type }
    var certificatePayload: SDKCertificatePayload? {
        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {
        log(error: " =============== Empty Enforcement for \(String(describing: type(of: self))) ===================================")
        if let payload = self.certificatePayload {
            let dict = payload.toDictionary()
            self.dataStore.certificatePayload = dict as NSDictionary
        }

        // TODO: enforce policy using payload, if given or using defaults if not given.
        self.enforcementComplete()
    }
}
