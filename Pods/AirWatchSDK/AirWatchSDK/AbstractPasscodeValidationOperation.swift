//
//  VerifyPasscodeOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import AWHelpers
import AWLocalization
import AWPresentation
import Foundation
import LocalAuthentication

protocol AbstractPasscodeValidationOperation: AuthenticationFailureMessagingProtocol {

    var passcodeValidator: PasscodeValidation { get }

    //MARK: Touch ID Unlock methods
    var isTouchIDAvailableToUnlock: Bool { get }
    var needsToConfigureTouchID: Bool { get }
    func unlockUsingTouchID(completion: ((_ successfullyUnlocked: Bool, _ touchIdUnlockError: Error?)->Void)?)

    //MARK: Validate User Input
    func takeActionBasedOn(_ passcode: String) -> PasscodeValidationResult

}

extension AbstractPasscodeValidationOperation where Self: SDKSetupAsyncOperation {
    //MARK: Touch ID Unlock methods
    var isTouchIDAvailableToUnlock: Bool {
        
		log(verbose: "Checking if TouchID is available")
        guard BiometricsHelper.isTouchIDSupported() else {
            log(verbose: "Device does not support TouchID")
            return false
        }
        log(verbose: "Device supports touch id, checking if profile has it enabled")
        let profileBiometricMethod = self.dataStore.SDKProfile?.authenticationPayload?.biometricMethod
        let isTouchIDConfigured = self.dataStore.isTouchIDConfigured
        let ret = (isTouchIDConfigured && profileBiometricMethod == AWSDK.BiometricMethod.touchID)
        log(verbose: "Status for touch id is: \(ret)")
        return ret
    }
    
    var needsToConfigureTouchID: Bool {
        
        log(verbose: "Checking if we need to configure TouchID")
        guard BiometricsHelper.isTouchIDSupported() else {
            log(verbose: "Device does not support TouchID")
            return false
        }
        
        log(verbose: "Device supports TouchID, checking if profile has it enabled")
        let profileBiometricMethod = self.dataStore.SDKProfile?.authenticationPayload?.biometricMethod
        guard profileBiometricMethod == AWSDK.BiometricMethod.touchID else {
            log(verbose: "profile does not have TouchID enabled")
            return false
        }
        
        guard self.dataStore.isTouchIDConfigured == false else {
            log(verbose: "touchid is already configured")
            return false
        }
        
        log(info: "TouchID is not configured already and profiles require it")
        return true
    }

    // If unlock with touchID is unsuccessful, then datastore.isTouchIDConfigured becomes false because either the user has added or deleted a fingerprint.
    func unlockUsingTouchID(completion: ((_ successfullyUnlocked: Bool, _ touchIdUnlockError: Error?)->Void)?) {

        self.dataStore.authenticateWithTouchID { [weak self] (success, error) in

            guard let weakSelf = self else {
                completion?(false, error)
                return
            }

            if success {
                weakSelf.markOperationComplete()
                completion?(true, nil)
                return
            }

            
            
            //If the touch Id is unavialbale due to change in finger prints, display message and on affirmation, show the username and password screen
            guard let errorCode = error?._code, weakSelf.dataStore.isTouchIDConfigured else  {
                //If touch id is unavialbale due to other reasons, show the username password screen immediately.
                completion?(false, error)
                return
            }
            
            if errorCode == Int(errSecItemNotFound) {
                //Reset the touch ID configured flag to make sure it will be configured properly on unlock again.
                weakSelf.dataStore.isTouchIDConfigured = false
                weakSelf.displayFingerPrintChangedAlert {
                    completion?(false, error)
                }
                return
            }
            
            // In this case where errSecAuthFailed, but TouchID is still available, we return no error beacuase user can still use TouchID
            if errorCode == Int(errSecAuthFailed), BiometricsHelper.isTouchIDSupported() {
                completion?(false, nil)
                return
            }
            //user cancelled or any other error
            completion?(false, error)
        }

   }

    fileprivate func displayFingerPrintChangedAlert(completion: (() -> Void)?) -> Void {

        let alertTitle = AWSDKLocalizedString("Notice")
        let alertMessage: String

        if self.dataStore.currentAuthenticationMethod == .passcode {
            alertMessage = AWSDKLocalizedString("CryptKeyRetrievalFromTouchIDFailedPasscodeMessage")
        } else {
            alertMessage = AWSDKLocalizedString("CryptKeyRetrievalFromTouchIDFailedCredentialsMessage")
        }

        let action = UIAlertAction(title: AWSDKLocalization.getLocalizationString("Ok"), style: .cancel) { (_) in
            completion?()
        }

        _ = KeyWindowAlert(title: alertTitle, message: alertMessage, actions: [action]).show()
    }

    //MARK: User input validation
    /**
     Action to take are...
        * OK - successful passcode and the action taken is markOperationComplete
        * wrongPasscode - Count the number of failures. If number of consecutive fails is greater than 2 of allowable failures and the number of allowable failed attempts is less than or equal to 3, then display blocker
        * maxFailedAttemptsMade - You have reached the maximum failed attempts allowed and wipe will occure and then restart the SDK
     */
    func takeActionBasedOn(_ passcode: String) -> PasscodeValidationResult {
        log(info: "Received passcode and will attempt to validate against storage")
        log(debug: "User entered Passcode:") //Do not print passcode ever to console.

        let passcodeState = passcodeValidator.validatePasscode(passcode)
        switch passcodeState {
        case .ok:
            DispatchQueue.main.async { self.sdkController.delegate?.controllerDidUnlockDataAccess?() }
            handleUnlockSuccessful(unlockType: UnlockType.passcode)

        case .wrongPasscode:
            handleUserEnteredWrongCredentials()

        case .maxFailedAttemptsMade:
            handleUserReachedMaximumUnlockAttempts()
        }
        return passcodeState
    }

    //MARK: Internal/Private Functions
    internal func handleUnlockSuccessful(unlockType: UnlockType) {
        log(info: "Passcode was valid")
#if sdk_mixpanel_data_collection_enabled
        SDKMixpanelDataCollectionService.sharedInstance?.track(event: SDKLifeCycleEvent.unlocked(unlockType))
#endif    
        self.dataStore.failedPasscodeUnlockAttempts = 0
        
        if self.needsToConfigureTouchID {
            self.dataStore.enableTouchIDAuthentication { (success: Bool, error: NSError?) in
                self.dataStore.isTouchIDConfigured = success
            }
        }

        guard unlockType == .passcode else {
            self.markOperationComplete()
            return
        }

        let complianceCheckOperation: PasscodeComplianceVerificationOperation = self.createOperation()

        complianceCheckOperation.completionBlock = { [weak self, weak complianceCheckOperation] in
            guard let operation = complianceCheckOperation else {
                self?.markOperationFailed()
                return
            }

            if operation.operationCompletedSuccessfully {
                self?.markOperationComplete()
            } else {
                self?.markOperationFailed()
            }
        }
        SDKOperationQueue.workerQueue.addOperation(complianceCheckOperation)
    }

}
