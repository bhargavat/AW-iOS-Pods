//
//  AuthenticationPolicyManager.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

class AuthenticationPolicyHelper {

    private var payload: AuthenticationPayload

    init(payload: AuthenticationPayload) {
        self.payload = payload
    }

    var requiresPasscodeAuthentication: Bool {
        // TODO: possible deviation from existing implementation.
        return self.payload.authenticationMethod == AWSDK.AuthenticationMethod.passcode
    }

    var requiresUsernamePasswordAuthentication: Bool {
        return self.payload.authenticationMethod == AWSDK.AuthenticationMethod.usernamePassword
    }

    var requiresAuthentication: Bool {
        return requiresPasscodeAuthentication ||
            requiresUsernamePasswordAuthentication
    }

    var requiredAuthenticationMethod: AWSDK.AuthenticationMethod {
        return payload.authenticationMethod
    }
}
