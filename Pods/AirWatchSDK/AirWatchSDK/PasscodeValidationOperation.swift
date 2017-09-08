//
//  VerifyPasscodeOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWLocalization
import AWPresentation


class PasscodeValidationOperation: SDKSetupAsyncOperation, AbstractPasscodeValidationOperation, PasscodeValidationViewControllerDelegate {

    let passcodeValidator: PasscodeValidation

    //MARK: Operation
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        passcodeValidator = PasscodeValidation(dataStore: dataStore)
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }

    override func startOperation() {
        log(info: "Starting Operation PasscodeValidationOperation")
        
        var touchIDOptions: TouchIDOptions = .none
        
        if self.isTouchIDAvailableToUnlock {
            touchIDOptions = .allowAndPrompt
            
            if (dataStore as? ApplicationDataStore)?.lockType == LockType.manual {
                touchIDOptions = [.allowTouchID]
            }
        }

        // Present passcode validation ui first before attempting with touch id
        self.presenter.enable()
        self.presenter.pushPasscodeValidation(delegate: self,
                                              touchIDOptions: touchIDOptions)
    }

    //MARK: PasscodeValidationViewControllerDelegate methods
    func passcodeValidator(_ passcode: String) -> PasscodeValidationResult {
        let result = self.takeActionBasedOn(passcode)
        return result
    }
    
    func unlockWithTouchID(completionHandler: @escaping (TouchIDResult) -> Void) {
        self.unlockUsingTouchID {[weak self] (unlocked, error) in
            guard error == nil else {
                log(error: "Authenticating with Touch ID Failed with Error: \(String(describing: error))")
                completionHandler(.unavailable)
                return
            }
            
            guard unlocked else {
                log(error: "User cancelled while Authenticating with Touch ID")
                completionHandler(.userCancelled)
                return
            }
            
            log(info: "Successfully Authenticated with Touch ID")
            completionHandler(.successfullyAuthenticated)
            self?.markOperationComplete()
        }
    }

    func showForgotPasscodeScreen() {
        log(info: "🤔🤔🤔🤔 User started Forgot passcode flow. 🤔🤔🤔🤔")
        let forgotPasscodeOperation = ForgotPasscodeOperation(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        forgotPasscodeOperation.completionBlock = {[weak self, weak forgotPasscodeOperation] in
            guard
                let currentOperation = self,
                let dependentOperation = forgotPasscodeOperation
                else {
                    log(error: "Unfortunately the forgot passcode operation has been released")
                    self?.markOperationFailed()
                    return
                }

            if dependentOperation.operationCompletedSuccessfully {
                currentOperation.markOperationComplete()
            }
        }
        SDKOperationQueue.workerQueue.addOperations([forgotPasscodeOperation], waitUntilFinished: false)
    }

}
