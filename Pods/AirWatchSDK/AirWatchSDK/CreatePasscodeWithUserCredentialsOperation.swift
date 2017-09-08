//
//  CreatePasscodeWithUserCredentialsOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWPresentation
import AWServices
import AWError

class CreatePasscodeWithUserCredentialsOperation: CredentialsAuthenticationOperation, AbstractDataStorePasscodeSetupOperation {
    var passcodeRestrictor: PasscodeCompliance

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        passcodeRestrictor = PasscodeCompliance(dataStore: dataStore)
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }

    
    override internal func startOperation() {
        let requiredIdentityType = self.dataStore.profileRequiredSingleSignOn ? IdentityType.common : IdentityType.application
        self.requiredIdentityType = requiredIdentityType
        
        if let username = self.dataStore.enrollmentAccount?.username,
            let password = self.dataStore.enrollmentAccount?.password {
            createPasscodeFromCredentials(username as String, password: password as String)
            self.markOperationComplete()
            return
        }

        super.startOperation()
    }

    override func identitySetupComplete() {
        guard let username = self.account?.username,
            let password = self.account?.password else {
                log(error: "error in setting up account")
                self.markOperationFailed()
                return
        }

        createPasscodeFromCredentials(username as String, password: password as String)
        //authentication from the server must be success at this point
        guard let identity = self.identity else {
            log(error: "error in setting up identity")
            self.markOperationFailed()
            return
        }
        
        self.dataStore.enrollmentAccount = self.account
        if self.requiredIdentityType == .common {
            self.dataStore.commonIdentity = identity
        } else {
            self.dataStore.applicationIdentity = identity
        }
        
         self.markOperationComplete()
    }

    internal func createPasscodeFromCredentials(_ username: String, password: String) {
        let passcode = "\(username)\(password)"
        let passcodeCreated = self.createDataStorePasscode(passcode, method: AWSDK.AuthenticationMethod.usernamePassword)
        let error = AWError.SDK.PasscodeCreation.failedToSetupNewPasscode
        self.completeDataStorePasscodeSetupOperation(passcodeCreated, error: error)
    }
}
