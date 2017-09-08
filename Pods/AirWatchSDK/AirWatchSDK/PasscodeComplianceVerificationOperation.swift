//
//  PasscodeComplianceVerificationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import AWPresentation
import AWLocalization
import Foundation
import AWServices

class PasscodeComplianceVerificationOperation: SDKSetupAsyncOperation {
    override func startOperation() {
        guard let payload = self.dataStore.SDKProfile?.authenticationPayload else {
            log(info: "Unlocking current application for the first time. Since we dont have profiles in the app. we dont check compliance yet!")
            self.markOperationComplete()
            return
        }

        // If the current authenticationMethod in the payload is same as what is currently saved,
        // then we need to make sure that the currently saved passcode still conforms to what is saved.

        guard payload.authenticationMethod == .passcode else {
            // If the authenticationMethod is UsernamePassword or Disabled, then everything is fine and we can complete this enforcer.
            self.markOperationComplete()
            return
        }

        //Current method is passcode, we will verify for the compliance
        log(debug: "Authentication methods match. Let's see if the passcode is compliant?")
        let isCurrentPasscodeCompliant = self.dataStore.isCurrentPasscodeCompliant(payload: payload)
        if isCurrentPasscodeCompliant {
            log(debug: "The passcode is compliant with the requirements.")
            self.markOperationComplete()
            return
        }

        log(debug: "Current Passcode is not compliant need to change the passcode.")
        self.verifyCurrentAuthenticationCompliance(payload: payload)
    }

    //
    private func verifyCurrentAuthenticationCompliance(payload: AuthenticationPayload) {
        let profileFetchOperation = ConfigurationProfileFetchOperation(profile: AWSDK.ConfigurationProfileType.sdk , operation: self)
        SDKOperationQueue.workerQueue.addOperations([profileFetchOperation], waitUntilFinished: true)
        if profileFetchOperation.operationCompletedSuccessfully,
            let profile = profileFetchOperation.fetchedProfile,
            let authenticationPayload = profile.authenticationPayload {
            //Save the profile to store so that the Update Operation will read an use it.
            _ = self.dataStore.saveProfile(profile)
            log(debug: "Fetched latest profile as current passcode is not compliant and have to change.")
            let isCurrentPasscodeCompliant = self.dataStore.isCurrentPasscodeCompliant(payload: authenticationPayload)
            if isCurrentPasscodeCompliant {
                log(debug: "The passcode is compliant with the latest requirements fetched from the server.")
                self.markOperationComplete()
                return
            }

            log(debug: "Current Passcode is still not compliant need to change the passcode.")
        }
        let complianceValidator = PasscodeCompliance(dataStore: self.dataStore)
        let passcodeComplianceStatus = complianceValidator.passcodeIsAgeCompliant()
        self.presentAlert(status: passcodeComplianceStatus)

        let updateOperation: UpdatePasscodeOperation = self.createOperation()
        SDKOperationQueue.workerQueue.addOperations([updateOperation], waitUntilFinished: true)
        if updateOperation.operationCompletedSuccessfully {
            self.markOperationComplete()
        } else {
            self.markOperationFailed()
        }
    }

    private func presentAlert(status: PasscodeComplianceResult) {
        let title = AWSDKLocalization.getLocalizationString("CreateNewPasscode")
        let nonCompliantReason: String
        if status.complianceMessage.lowercased() == "passcode age has expired" {
            nonCompliantReason = AWSDKLocalization.getLocalizationString("MaximumPasscodeAgeHasExpired")
        } else {
            nonCompliantReason = AWSDKLocalization.getLocalizationString("PasscodeRequirementChanged")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Wait until, the presentation is complete from under the hood.
            let action = UIAlertAction(title: AWSDKLocalization.getLocalizationString("Create"), style: .default, handler: nil)
            let _ = KeyWindowAlert(title: title, message: nonCompliantReason, actions: [action]).show()
        }
    }
    
}
