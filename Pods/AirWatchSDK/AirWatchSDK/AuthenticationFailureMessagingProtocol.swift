//
//  AuthenticationFailureMessagingProtocol.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWError
import AWLocalization

internal protocol AuthenticationFailureMessagingProtocol {
    func handleUserEnteredWrongCredentials()
    func displayAlert(_ remainingAttempts: Int)
    func handleUserReachedMaximumUnlockAttempts()
    
}

internal extension AuthenticationFailureMessagingProtocol where Self: SDKSetupAsyncOperation  {
    
    var maximumAllowedUnlockAttempts: Int {
        guard let maxAttempts = self.dataStore.SDKProfile?.authenticationPayload?.maximumFailedAttempts else {
            // This condition should never be reached because this operation should not run unless there's a profile
            log(error: "Cannot call PasscodeValidationOperation because either the payload or authentication payload was nil")
            log(verbose: "SDK Profile: \(self.dataStore.SDKProfile?.description ?? "Not found")")
            log(verbose: "AuthenticationPayload: \(self.dataStore.SDKProfile?.authenticationPayload?.description ?? "NO authentication payload found in SDK profile" )")
            return Int.max
        }
        return maxAttempts
    }
    
    internal func handleUserEnteredWrongCredentials() {
        log(error: "Attempted to unlock with bad passcode")
        print("maxNumberOfFailedAttemptsAllowed: \(self.maximumAllowedUnlockAttempts)")
        let totalFailedAttempts = self.dataStore.failedPasscodeUnlockAttempts
        let remainingUnlockAttempts = self.maximumAllowedUnlockAttempts - totalFailedAttempts
        
        self.displayAlert(remainingUnlockAttempts)
    }
    
    internal func displayAlert(_ remainingAttempts: Int) {
        log(info: "Number of attempts left to wipe device is \(remainingAttempts)")
        
        let alert = self.createUserMessageAlert(remainingAttempts)
        
        _ = alert.show()
    }
    
    internal func handleUserReachedMaximumUnlockAttempts() {
        log(error: "Too many attempts made when entering passcode")
        log(info: "Sending request to server to unenroll device")
        
        guard let store = self.dataStore as? ApplicationDataStore else {
            log(error: "Invalid Store, cannot wipe application data")
            self.markOperationFailed()
            return
        }
        
        let operation: SDKOperation
        if store.shared {
            operation = CurrentUserLogoutOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        } else {
            operation = DataStoreCleanupOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        }
        
        let currentValidationOperation = self
        operation.completionBlock = {
            currentValidationOperation.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.userFailedtoUnlockProtectedDataInMaximumAllowedAttempts)
            currentValidationOperation.markOperationFailed()
            DispatchQueue.main.async {
                AWController.sharedInstance.start()
            }
        }
        
        SDKOperationQueue.workerQueue.addOperation(operation)
    }
    
    
    func createUserMessageAlert(_ remainingAttempts: Int) -> KeyWindowAlert {
        var alertTitle = "Error".localized
        if remainingAttempts == 1 {
            alertTitle = "Warning".localized
            return KeyWindowAlert(title: alertTitle, message: "LastAuthenticationAttemptWipeWarning".localized)
        }
        
        if remainingAttempts <= 2 {
            alertTitle = "Notice".localized
            let message = String(format: "AttemptsLeftMessage".localized, remainingAttempts)
            return KeyWindowAlert(title: alertTitle, message: message)
        }
        
        if self.dataStore.currentAuthenticationMethod == .usernamePassword {
            return KeyWindowAlert(title: alertTitle, message: "InvalidCredentialsTitle".localized)
        }
        return KeyWindowAlert(title: alertTitle, message:"IncorrectPasscodeEntered".localized)
    }
}
