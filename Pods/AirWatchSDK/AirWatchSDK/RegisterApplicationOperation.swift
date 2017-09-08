//
//  RegisterApplicationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWServices

extension AWError.SDK {
    public enum RegisterApplication: AWErrorType {
        case failedToRegisterApplication
        case missingHMACToken
    }
}

class RegisterApplicationOperation: IdentitySetupOperation {
    var registerApplicationResult: AWServices.RegistrationResult = .unknown

    var commonIdentity: Identity? = nil

    override func startOperation() {

        guard commonIdentity != nil else {
            log(error: "Should have a Common Identity Setup to resgister application")
            self.markOperationFailed()
            return
        }

        self.requiredIdentityType = .application
        super.startOperation()
    }

    override func performAuthentication() {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            log(error: "Can not resgister the application without Bundle ID")
            return
        }

        guard let hmacAuthorizer = SDKHMACAuthorizer(identity: commonIdentity),
            let enrollmentServices = self.dataStore.commonEnrollmentServices else {
            log(error: "Common Identity HMAC is nil but trying to set application hmac from common hamc")
            return
        }

        enrollmentServices.registerApplication(bundleID, commonIdentityAuthorizer: hmacAuthorizer) {[weak self] (response, error) in
            self?.registerApplicationResult = response?.result ?? .unknown
            log(error: "Register Application returned Registration result: \(String(describing: response?.result))")
            guard error == nil, let response = response, response.result == .enrollmentComplete else {
                log(error: "Register Application Failed with error: \(String(describing: error))")
                self?.identitySetupError = AWError.SDK.RegisterApplication.failedToRegisterApplication
                self?.identity = nil
                self?.markOperationFailed()
                return
            }
            
            guard let hmacToken = response.hmacToken else {
                log(error: "Enrollment Completed but did not return any application specific HMAC Token")
                self?.identitySetupError = AWError.SDK.RegisterApplication.missingHMACToken
                self?.markOperationFailed()
                return
            }


            self?.createIdentity(hmacToken: hmacToken, account: nil)
        }
    }

    override func identitySetupComplete() {
        self.markOperationComplete()
    }
}
