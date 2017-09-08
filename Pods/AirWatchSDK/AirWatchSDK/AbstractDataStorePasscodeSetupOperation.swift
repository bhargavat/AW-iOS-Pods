//
//  CreatePasscodeOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

import AWServices
import AWPresentation
import AWLocalization
import AWError

extension AWError.SDK {
    enum PasscodeCreation: AWErrorType {
        case failedToSetupNewPasscode
    }
}

protocol AbstractDataStorePasscodeSetupOperation {

    var passcodeRestrictor: PasscodeCompliance { get }

    func resetDataStoreUpdatedPasscodeSettings(_ passcode: String, method: AWSDK.AuthenticationMethod)
    func scheduleAuxilliaryDataStoreSetupOperations()
    func createDataStorePasscode(_ passcode: String, method: AWSDK.AuthenticationMethod) -> Bool
    func changeDataStorePasscode(_ oldPasscode: String, newPasscode: String) -> Bool
    func completeDataStorePasscodeSetupOperation(_ operationSuccess: Bool, error: Error?)
}

extension AbstractDataStorePasscodeSetupOperation where Self: SDKSetupAsyncOperation {

    func resetDataStoreUpdatedPasscodeSettings(_ passcode: String, method: AWSDK.AuthenticationMethod) {
        self.dataStore.isPasscodeSet = true
        self.dataStore.currentPasscodeSetDate = Date()
        self.dataStore.failedPasscodeUnlockAttempts = 0
        self.dataStore.currentAuthenticationMethod = method
        self.dataStore.currentBiometricMethod = AWSDK.BiometricMethod.none
        self.dataStore.isTouchIDConfigured = false
        self.dataStore.needToEscrowPasscode = true
    }

    func scheduleAuxilliaryDataStoreSetupOperations() {
        let biometricsSetupOperation = BiometricsSetupOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        SDKOperationQueue.workerQueue.addOperations([biometricsSetupOperation], waitUntilFinished: false)
    }

    func createDataStorePasscode(_ passcode: String, method: AWSDK.AuthenticationMethod) -> Bool {

        let successfullyCreatedNewPasscode = self.dataStore.createPasscode(newPasscode: passcode)
        if successfullyCreatedNewPasscode {
            self.resetDataStoreUpdatedPasscodeSettings(passcode, method: method)
        }

        return successfullyCreatedNewPasscode
    }

    func completeDataStorePasscodeSetupOperation(_ operationSuccess: Bool, error: Error?) {

        if operationSuccess, error == nil {
            self.scheduleAuxilliaryDataStoreSetupOperations()
            self.markOperationComplete()
            return
        }
        
        log(error: "Can not create Passcode. Error: \(String(describing: error))")
        self.markOperationFailed()
    }

    
    func changeDataStorePasscode(_ oldPasscode: String, newPasscode: String) -> Bool {
        let changePasscodeSuccessful = self.dataStore.changePasscode(oldPasscode: oldPasscode, newPasscode: newPasscode)
        if changePasscodeSuccessful {
            self.resetDataStoreUpdatedPasscodeSettings(newPasscode, method: AWSDK.AuthenticationMethod.passcode)
        }
        return changePasscodeSuccessful
    }
}
