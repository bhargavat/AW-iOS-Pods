//
//  ApplicationIdentitySetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWNetwork
import AWHelpers
import AWError
import AWLocalization

extension AWError.SDK {
    public enum ApplicationRegistration: AWErrorType {
        case failedToRegisterApplication
    }
}

class ApplicationIdentitySetupOperation: SDKSetupAsyncOperation {

    func shouldSetupCommonIdentity() -> Bool {
        return self.dataStore.commonIdentity?.authorization != nil
    }

    override func startOperation() {
        log(info: "Creating Application Identity")
        //Check if Single Sign on is required.
        let enabledSingleSignOn = self.dataStore.profileRequiredSingleSignOn
        log(info: "Single Sign On status: \(enabledSingleSignOn)")

        // Make sure common identity exists..
        var commonIdentityExists = self.shouldSetupCommonIdentity()
        var commonIdentityCreated = false
        if commonIdentityExists == false {
            //Setup common identity. Capture Account Credentials.
            commonIdentityCreated = self.setupCommonIdentity()
            commonIdentityExists = commonIdentityCreated
            if commonIdentityCreated {
                log(info: "Created Common Identity as part of creating Application Identity. Common Identity exists now.")
            }
        }
        guard commonIdentityExists else {
            log(error: "Can not create Common Identity. Failing Application Identity setup operation as well.")
            self.markOperationFailed()
            return
        }

        // Now, let's not worry about common identity any more.
        // Let's setup Application Identity...
        var shouldUseCommonIdentityForApplicationIdentity = false

        // Check if the current account is set with Either Token/SAML.
        // Token/SAML with SSO off is not documented. We assume that the user is coming from Token/SAML route
        // and we have used the token to create common identity. But we cannot use the same one for app identity.
        // Since we have used our token for Common Identity, this app will get its application hmac from common hmac and use it.
        // when SSO off, and second application will not have enrollment account in non shared data store so we will directly 
        // use that for application hmac.
        if let account = self.dataStore.enrollmentAccount,
            account.authenticationCredentialsType == .authorizationToken {
            shouldUseCommonIdentityForApplicationIdentity = true
        } else if enabledSingleSignOn {
            shouldUseCommonIdentityForApplicationIdentity = enabledSingleSignOn
        }

        if self.dataStore.commonIdentity?.authorization == nil {
            shouldUseCommonIdentityForApplicationIdentity = false
        }

        if let identity = self.dataStore.commonIdentity, shouldUseCommonIdentityForApplicationIdentity {
            log(info: "Single Sign on is \(enabledSingleSignOn) and Common Identity exists. Should use Common Identity to get application Identity.")
            log(info: "If this fails to get application Identity, it should start all the way from common identity")
            self.createApplicationIdentity(commonIdentity: identity)
            return
        }


        if let account = self.dataStore.enrollmentAccount,
            account.authenticationCredentialsType == .usernamePassword {
            log(info: "Single Sign on is not enabled but account credentials exists from Common Identity creation.")
            log(info: "Will create Application Identity from these credentials.")
            self.createApplicationIdentity(account: account)
            return
        }
        
        log(info: "We have exhausted all options for silent hmac registration. Have to ask for user credentails.")
        log(info: "Will create Application Identity from these credentials.")
        self.createApplicationIdentity()
    }
    
    func createApplicationIdentity(commonIdentity: Identity) {
        let operation:RegisterApplicationOperation = self.createOperation()
        operation.requiredIdentityType = .application
        operation.commonIdentity = commonIdentity
        
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
        switch operation.registerApplicationResult {
        case .enrollmentComplete:
            self.prepareApplicationIdentity(operation: operation)
            
        case .enrollmentBlocked:
            log(error: "When registering application, operation's status was that of being blocked")
            self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.registeringApplicationBlocked)
            self.showEnrollmentBlockedMessage()
            self.markOperationFailed()

        default:
            log(error: "Current Registration Status: \(operation.registerApplicationResult)")
            self.showInvalidApplicationError()
            self.markOperationFailed()
        }
    }
    
    func createApplicationIdentity(account: AWEnrollmentAccount) {
        let operation: ExistingCredentialsAuthenticationOperation = self.createOperation()
        operation.requiredIdentityType = .application
        operation.account = account
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
        self.prepareApplicationIdentity(operation: operation)
    }

    func createApplicationIdentity() {
        let operation: CoreIdentitySetupOperation = self.createOperation()
        operation.requiredIdentityType = .application
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
        self.prepareApplicationIdentity(operation: operation)
    }

    func setupCommonIdentity() -> Bool {
        log(debug: "Setting up Common Identity first...")
        let operation: CoreIdentitySetupOperation = self.createOperation()
        operation.requiredIdentityType = .common
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
        self.prepareCommonIdentity(operation: operation)
        return operation.operationCompletedSuccessfully
    }
    
    // Should only pass an operation which is ONLY application identity
    func prepareApplicationIdentity(operation: IdentitySetupOperation) {

        guard operation.operationCompletedSuccessfully, operation.identitySetupError == nil else {
            log(error: "Application Identity Setup: Operation \(operation) failed. Error: \(String(describing: operation.identitySetupError))")
            self.dataStore.applicationIdentity = nil
            self.dataStore.enrollmentAccount = nil
            // Should not be clearing common identity when preparing application identity and failing
            
            //Clear everything and restart the operation. If it fails, it fails over common identity as well.
            self.startOperation()
            
            return
        }

        self.dataStore.applicationIdentity = nil
        self.dataStore.applicationIdentity = operation.identity

        if operation.account != nil {
            //Make sure we dont overwrite existing account with nil account from application identity
            self.dataStore.enrollmentAccount = nil
            self.dataStore.enrollmentAccount = operation.account
        }

        self.updateUserInformtion()
    }
    
    func prepareCommonIdentity(operation: IdentitySetupOperation) {
        guard operation.operationCompletedSuccessfully, operation.identitySetupError == nil else {
            log(error: "Common Identity Setup: Operation \(operation) failed. Error: \(String(describing: operation.identitySetupError))")
            self.dataStore.applicationIdentity = nil
            self.dataStore.enrollmentAccount = nil;
            self.dataStore.commonIdentity?.authorization = nil
            
            //Clear everything and restart the operation. If it fails, it fails over common identity as well.
            self.markOperationFailed()
            self.showInvalidSettingsError()
            return
        }
        
        self.dataStore.commonIdentity = operation.identity
        self.dataStore.enrollmentAccount = operation.account
    }
    
    
    func updateUserInformtion() {
        let operation: UserChangeDetectionOperation = self.createOperation()
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
        self.markOperationComplete()
    }
    
    func showInvalidSettingsError() {
        let _ = KeyWindowAlert(title: "Error", message: "Can not use the settings provided by MDM server. Please enter your username and password to login.").show()
    }
    
    private func showEnrollmentBlockedMessage() {
        _ = KeyWindowAlert(title: "Error", message: AWSDKLocalization.getLocalizationString("NotMDMEnrolledErrorMessage")).show()
    }
    
    fileprivate func showInvalidApplicationError() {
        let action = UIAlertAction(title: AWSDKLocalization.getLocalizationString("Ok"), style: .default, handler: nil)
        _ = KeyWindowAlert(title: "Error", message: AWSDKLocalization.getLocalizationString("InvalidCredentialsTitle"), actions: [action]).show()
    }
}
