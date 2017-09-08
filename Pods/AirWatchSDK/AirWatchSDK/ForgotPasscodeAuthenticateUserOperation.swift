//
//  ForgotPasscodeAuthenticateUserOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWHelpers
import AWPresentation
import AWLocalization

class ForgotPasscodeAuthenticateUserOperation: CoreIdentitySetupOperation {
    
    internal override func startOperation() {
        let requiredIdentityType = self.dataStore.profileRequiredSingleSignOn ? IdentityType.common : IdentityType.application
        self.requiredIdentityType = requiredIdentityType
        super.startOperation()
    }

    internal override func performAuthentication() {
        
        let samlAuthenticationOperation: SAMLAuthenticationOperation = self.createOperation()
        if self.performAuthentication(operation: samlAuthenticationOperation) {
            self.markOperationComplete()
            return
        }
        log(error: "Error Getting Identity using SAML: \(samlAuthenticationOperation.identitySetupError?.errorDescription ?? "SAML authentication operation failed with an error")")
        
        let credentialAuthenticationOperation: CredentialsAuthenticationOperation = self.createOperation()
        credentialAuthenticationOperation.authenticationOptions = AuthenticationOptions.passcodeResetOptions
        if self.performAuthentication(operation: credentialAuthenticationOperation) {
            self.markOperationComplete()
            return
        }
        log(error: "Error Setting up Identity using Credentials: \(credentialAuthenticationOperation.identitySetupError?.errorDescription ?? "Credential authentication operation failed with an error")")
        
    }
    
    override func setupIdentity(operation: IdentitySetupOperation) {
        if let account = operation.account {
            self.account = account
            log(info: "User Account from forgot passcode: \(account)")
        }
        
        if let identity = operation.identity {
            log(info: "Auth Group from identity: \(identity.authorization?.authorizationGroup ?? "No group identity or identity authroization")")
            log(info: "Required Identity Type is \(self.requiredIdentityType) and Identity HMAC \(identity.authorization?.hmacToken ?? "could not be retrieved from identity authorization")")
            self.identity = identity
        }
        
        // We need to make sure the user is not different from previously logged in user.
        self.verifyCurrentUser()
    }


    private func verifyCurrentUser() {
        let operation: UserChangeDetectionOperation = self.createOperation()
        operation.completionBlock = {
            self.markOperationComplete()
        }
        SDKOperationQueue.workerQueue.addOperation(operation)
    }
}
