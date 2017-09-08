//
//  ForgotPasscodeOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWHelpers

class ForgotPasscodeOperation: SDKSetupAsyncOperation {

    func displayRequiredAuthenticationError() {
        _ = KeyWindowAlert(title: "Error", message: "You need to authentication first to reset your passcode.").show()
    }

    func displayKeyWasNeverEscrowedError() {
        _ = KeyWindowAlert(title: "Error", message: "Unable to determine your old passcode. You should enter passcode to get your data back or reset completely from SSP").show()
    }


    override func startOperation() {
        log(info: "Starting Forgot Passcode Operation")
        let userAuthOperation = ForgotPasscodeAuthenticateUserOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        let escrowKeyFetchOperation = EscrowedKeyFetchOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        let updatePasscodeOperation = UpdatePasscodeOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)

        /* Authenticate and retrieve hmac ▶︎ hold on to hmac(could be common/app) and account
         * ▶︎ EscrowKeyFetchOperation (using retrieved hmac) ▶︎ Unlock dataStore using fetched
         * cryptKey ▶︎ CreateNewPasscode ▶︎ ChangePasscodeFromOldToNew ▶︎ Save retrieved hmac and
         * account ▶︎ Done
         */
        SDKOperationQueue.workerQueue.addOperations([userAuthOperation], waitUntilFinished: true)
        guard userAuthOperation.operationCompletedSuccessfully else {
            if userAuthOperation.isCancelled {
                // In case the operation was canceled by the user via the cancel button we just need to end this operation
                // self.markOperationFailed() could have been called after the else, but for clarity this is called here
                self.markOperationFailed()
            } else {
                self.displayRequiredAuthenticationError()
                self.markOperationFailed()
            }
            return
        }
        
        
        guard let identity = userAuthOperation.identity, let enrolledAccount = userAuthOperation.account else {
            self.markOperationFailed()
            log(error: "failed to complete ForgotPasscodeAuthenticateUserOperation successfully")
            return
        }
        escrowKeyFetchOperation.identity = identity

        SDKOperationQueue.workerQueue.addOperations([escrowKeyFetchOperation], waitUntilFinished: true)
        guard
            escrowKeyFetchOperation.operationCompletedSuccessfully,
            let escrowedCryptKey = escrowKeyFetchOperation.fetchedCryptKey else {
            self.displayKeyWasNeverEscrowedError()
            self.markOperationFailed()
            return
        }
        
        log(info: "successfully retrieved cryptKey from escrowKeyFetchOperation in forgot passcode flow")
        updatePasscodeOperation.currentKey = ManagedKey.cryptKey(escrowedCryptKey)
        SDKOperationQueue.workerQueue.addOperations([updatePasscodeOperation], waitUntilFinished: true)

        if updatePasscodeOperation.operationCompletedSuccessfully {
            //we are sure we are unlocked, save identity and enrolled account
            self.saveIdentity(identity: identity, account: enrolledAccount)
            self.markOperationComplete()
        } else {
            self.markOperationFailed()
        }
    }
    
    
    internal func saveIdentity(identity: Identity, account: AWEnrollmentAccount?) {
        if let account = account, account.username.characters.count > 0 && account.password.characters.count > 0 {
            self.dataStore.enrollmentAccount = account
        }

        if identity.authorization?.authorizationGroup == IdentityType.common.authenticationGroup {
            log(info: "successfully saving common identity from forgot passcode flow")
            self.dataStore.commonIdentity = identity
        } else {
            log(info: "successfully saving application identity from forgot passcode flow")
            self.dataStore.applicationIdentity = identity
        }
    }

}
