//
//  Policy.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWError
import Foundation



extension ProfilePayload {
    static var type: String {
        return payloadType() ?? "Unknown"
    }
}

extension Profile {

    public func getPayload<T: ProfilePayload>(_ payloadType: String) -> T? {
        var payload: ProfilePayload? = nil
        switch payloadType {
        case AnalyticsPayload.type:         payload = self.analyticsPayload
        case AuthenticationPayload.type:    payload = self.authenticationPayload
        case BrandingPayload.type:          payload = self.brandingPayload
        case SDKCertificatePayload.type:    payload = self.certificatePayload
        case CompliancePayload.type:        payload = self.compliancePayload
        case ContentFilteringPayload.type:  payload = self.contentFilteringPayload
        case CustomPayload.type:            payload = self.customPayload
        case GeofencePayload.type:          payload = self.geofencePayload
        case IdentityPayload.type:          payload = self.identityPayload
        case LoggingPayload.type:           payload = self.loggingPayload
        case NetworkAccessPayload.type:     payload = self.networkAccessPayload
        case OfflineAccessPayload.type:     payload = self.offlineAccessPayload
        case SDKProxyPayload.type:          payload = self.proxyPayload
        case RestrictionsPayload.type:      payload = self.restrictionsPayload
        case WebsiteFilteringPayload.type:  payload = self.websiteFilteringPayload
        default: payload = nil
        }

        if let payload = payload {
            return payload as? T
        }

        return nil
    }
}

enum PolicyEnforcementStatus {
    case enforcementNotStarted
    case enforcementInProgress
    case enforcementComplete
    case enforcementFailed(Error)
}

// MARK: - Policy Enforcement Operation Class
class PolicyEnforcementOperation: SDKSetupAsyncOperation {
    var profile: Profile? {
        return dataStore.SDKProfile
    }

    var enforcementStatus = PolicyEnforcementStatus.enforcementNotStarted
    var payloadType: String {
        fatalError("should be provided by subclass")
    }

    override final func startOperation() {
        log(verbose: ">>> Starting Enforcement: \(self.payloadType)")
        self.enforcementStatus = PolicyEnforcementStatus.enforcementInProgress
        do {
            try enforce()
        } catch let error {
            enforcementComplete(error)
            return
        }
    }

    // MARK: Complete Async Operation method
    final func enforcementComplete(_ error: Error? = nil) {

        if let error = error {
            self.enforcementStatus = PolicyEnforcementStatus.enforcementFailed(error)
            log(error: "Failed Enforcement: \(self.payloadType), Error: \(error)")
            self.markOperationFailed()
        } else {
            self.enforcementStatus = PolicyEnforcementStatus.enforcementComplete
            log(verbose: "Completed enforcement: \(self.payloadType)")
            self.markOperationComplete()
        }

    }
    // MARK: method to overide in each policy enforcer
    func enforce() throws {
        fatalError("Should be overriden by sub classes")/// Emtpy policy enforcement
    }
}
