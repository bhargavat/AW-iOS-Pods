//
//  CoreIdentitySetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


import AWServices
import AWError
import AWLocalization
import AWPresentation

class CoreIdentitySetupOperation: IdentitySetupOperation {

    internal override func performAuthentication() {
        let managedTokenAuthentication: ManagedTokenAuthenticationOperation = self.createOperation()
        managedTokenAuthentication.requiredIdentityType = self.requiredIdentityType
        if self.performAuthentication(operation: managedTokenAuthentication) {
            self.markOperationComplete()
            return
        }
        log(error: "Error Setting up Identity using Managed Token: \(String(describing: managedTokenAuthentication.identitySetupError))")

        let samlAuthenticationOperation: SAMLAuthenticationOperation = self.createOperation()
        samlAuthenticationOperation.requiredIdentityType = self.requiredIdentityType
        if self.performAuthentication(operation: samlAuthenticationOperation) {
            self.markOperationComplete()
            return
        }
        log(error: "Error Setting up Identity using SAML: \(String(describing: samlAuthenticationOperation.identitySetupError))")

        let credentialAuthenticationOperation: CredentialsAuthenticationOperation = self.createOperation()
        credentialAuthenticationOperation.requiredIdentityType = self.requiredIdentityType
        credentialAuthenticationOperation.authenticationOptions = AuthenticationOptions.identitySetupOptions
        if self.performAuthentication(operation: credentialAuthenticationOperation) {
            self.markOperationComplete()
            return
        }
        // If the user clicks the back button when forgot passcode when using passcode auth mode during forgotpasscode operation, then the credentialsAuthenticationOperation fails the operation with identitySetupError with the value AWSDKError.CredentialsAuthentication.userCancelledAuthentication
        if credentialAuthenticationOperation.identitySetupError?.error != AWSDKError.CredentialsAuthentication.userCancelledAuthentication.error {
            log(error: "Error Setting up Identity using Credentials: \(String(describing:credentialAuthenticationOperation.identitySetupError))")
            self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.applicationIdentityNotSet)
        }
        self.markOperationFailed()
    }

    internal func performAuthentication(operation: IdentitySetupOperation) -> Bool {
        operation.requiredIdentityType = self.requiredIdentityType
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)

        guard operation.operationCompletedSuccessfully, operation.identitySetupError == nil else {
            return false
        }

        self.setupIdentity(operation: operation)
        return true
    }

    func setupIdentity(operation: IdentitySetupOperation) {
        log(info: "Copying Identity information from: \(operation)")
        self.account = operation.account
        self.identity = operation.identity
        self.identitySetupError = operation.identitySetupError
        log(info: "Completed Identity Setup for \(self.requiredIdentityType) with Error: \(String(describing: self.identitySetupError))")
    }
    
}
