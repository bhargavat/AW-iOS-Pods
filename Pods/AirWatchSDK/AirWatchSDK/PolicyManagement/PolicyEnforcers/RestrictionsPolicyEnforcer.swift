//
//  RestrictionsPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import AWServices
import Foundation

class RestrictionsPolicyEnforcer: PolicyEnforcementOperation {
    override var payloadType: String { return RestrictionsPayload.type }
    
    var restrictionsPayload: RestrictionsPayload? {
        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {
        let settings = SDKDefaultSettings.sharedSettings
        
        // Does not depend on Payload to apply blocking of third party keyboard
        self.swizzleThirdPartyKeyboard(defaultSettings: settings)
        
        guard let payload: RestrictionsPayload = restrictionsPayload else {
            log(debug: "No restrictions payload: Nothing to enforce")
            self.enforcementComplete()
            return
        }
        
        self.setupClipboardRestriction(payload: payload)
        self.setupURLSchemeInterceptorUsingRestriction(payload: payload, defaultSettings: settings)
        
        log(info: "Done Enforcing Resctrictions Policy")
        self.enforcementComplete()
    }
    
    private func swizzleThirdPartyKeyboard(defaultSettings: SDKDefaultSettings) {
        let isThirdPartyKeyboardAllowed = defaultSettings.isThirdPartyKeyboardEnabled()
        if isThirdPartyKeyboardAllowed == false {
            SDKCustomKeyboardController.shared.disableCustomKeyboards()
        }
    }
    private func setupClipboardRestriction(payload: RestrictionsPayload) {
        let sharedAWClipboard: AWClipboard = AWClipboard.sharedInstance()
        sharedAWClipboard.preventCopyPaste = payload.preventCopyPaste
    }
    private func setupURLSchemeInterceptorUsingRestriction(payload: RestrictionsPayload, defaultSettings: SDKDefaultSettings) {
        let interceptor: AWURLSchemeInterceptor = AWURLSchemeInterceptor.sharedInstance()
        interceptor.dataLossPreventionEnabled = payload.enableDataLossPrevention
        interceptor.redirectComposeEmailEnabled = defaultSettings.isRedirectComposeEmailEnabled()
        interceptor.redirectWebURLEnabled = defaultSettings.isRedirectWebURLEnabled()
        interceptor.updateInterceptingActivity() /// this will turn itself on or off depending on the settings
    }
}
