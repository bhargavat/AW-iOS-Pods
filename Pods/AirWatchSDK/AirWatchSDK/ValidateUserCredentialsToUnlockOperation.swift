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
import AWLocalization
import AWPresentation

fileprivate enum AuthenticationResult {
    case authenticated
    case authenticationFailed
    case workOffline
//  case serverNotReachable
}

internal class ValidateUserCredentialsToUnlockOperation: CredentialsAuthenticationOperation, AbstractPasscodeValidationOperation, AbstractDataStorePasscodeSetupOperation {
    private var username: String = ""
    private var password: String = ""

    let passcodeValidator: PasscodeValidation
    let passcodeRestrictor: PasscodeCompliance
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        self.passcodeValidator = PasscodeValidation(dataStore: dataStore)
        self.passcodeRestrictor = PasscodeCompliance(dataStore: dataStore)
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        self.authenticationOptions = AuthenticationOptions.unlockOptions
    }
    
    internal override func startOperation() {
        let requiredIdentityType = self.dataStore.profileRequiredSingleSignOn ? IdentityType.common : IdentityType.application
        self.requiredIdentityType = requiredIdentityType
        super.startOperation()
    }


    override func performAuthentication() {
        self.presenter.enable()
        self.unlockWithCredentials()
    }

    func unlockWithCredentials() {
        var options = AuthenticationOptions.allowRememberUsername
        var touchIDOptions = TouchIDOptions.none
        
        if SDKDefaultSettings.sharedSettings.isWorkOnlineButtonVisible() {
            options.insert(.allowWorkingOffline)
        }

        if self.isTouchIDAvailableToUnlock {
            touchIDOptions = TouchIDOptions.allowAndPrompt
            
            // Touch ID is available. However, if it is manual lock, show username and password screen.
            if (dataStore as? ApplicationDataStore)?.lockType == LockType.manual {
                touchIDOptions = [.allowTouchID]
            }
        }

        self.presenter.presentAuthentication(options: options, touchIDOptions: touchIDOptions,  delegate: self)
    }

    override func login(username: String, password: String, rememberUser: Bool, workOffline: Bool, completionHandler: @escaping (Bool) -> Void ) {
        self.username = username
        self.password = password

        guard workOffline == false else {
            //Dont go for server. try to unlcok locally.
            self.unlockLocalStore(authenticationResult: .workOffline)
            return
        }
        
        super.login(username: username, password: password, rememberUser: false, workOffline: false) { (success) in
            if success {
                self.dataStore.username = username // remember username for next time
            }
            completionHandler(success)
        }
    }
    
    override func unlockWithTouchID(completionHandler: @escaping (TouchIDResult) -> Void) {
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

    override func login(authenticationToken: String, completionHandler: @escaping (Bool)->Void) {
        log(error: "Can not use token while authenticating.")
        //Probably display a message
        completionHandler(false)
    }

    override func identitySetupComplete() {
        self.unlockLocalStore(authenticationResult: .authenticated)
    }

    override func rememberedUsernameToAutofill() -> String? {
        return self.dataStore.username
    }

    internal override func authenticationFailed(error: NSError?) {
        //check network connectivity.
        var networkStatus = Reachability.forInternetConnection?.currentReachabilityStatus ?? .notReachable
        if let serverAddress = self.dataStore.enrollmentInformation?.hostname {
            networkStatus = Reachability(hostname: serverAddress)?.currentReachabilityStatus ?? .notReachable
        }
        
        if networkStatus == .notReachable {
            self.unlockLocalStore(authenticationResult: .workOffline)
        } else {
            self.unlockLocalStore(authenticationResult: .authenticationFailed)
        }
    }

    private func unlockLocalStore(authenticationResult: AuthenticationResult) {

        guard
            self.username.characters.count > 0,
            self.password.characters.count > 0
        else {
            log(error: "Unknown why I can unlock with out username and password")
            return
        }
        let passcode = self.username+self.password
        let storageUnlockResult = self.passcodeValidator.validatePasscode(passcode)

        //Function that handle where the validation with server is failed
        func handleValidationFailure() -> () {
            let maximumAttempts = self.dataStore.SDKProfile?.authenticationPayload?.maximumFailedAttempts ?? Int.max
            let remainingAttempts = maximumAttempts - self.dataStore.failedPasscodeUnlockAttempts
            if remainingAttempts <= 0 {
                self.handleUserReachedMaximumUnlockAttempts()
            } else {
                self.handleUserEnteredWrongCredentials()
            }
        }

        switch (authenticationResult, storageUnlockResult) {

        case (.authenticated, .ok):
            //Everything is OK. User is successfull in both validation and unlocking the store.
            self.saveIdentity(identity: self.identity)
            self.handleUnlockSuccessful(unlockType: .usernamePassword)
            
            
        case (.authenticated, .wrongPasscode ): fallthrough
        case (.authenticated, .maxFailedAttemptsMade ):
            // Server Validated the credentials. Looks like Storage Credentials are outdated.
            //Will update store credentials either by using the escrowed key or creating a new store with new username+password combination.
            DispatchQueue.global(qos: .background).async {
                self.updateAuthenticatedPasscode(passcode: passcode)
            }

        case (.workOffline, .ok):
            //We trust user is offline but knows his/her password. We allow access in this case to use the application.
            self.handleUnlockSuccessful(unlockType: .usernamePassword)
            
        case (.workOffline, .wrongPasscode): fallthrough
        case (.workOffline, .maxFailedAttemptsMade):
            //could not authenticate from server and local authentication also failed..
            handleValidationFailure()

        case (.authenticationFailed, .ok):
            //We think user is using new password to unlock outdated store. But we still count towards failed attempts to unlock.
            // We will display a message to user to use proper credentials.
            let alertAction = UIAlertAction(title: AWSDKLocalization.getLocalizationString("Ok"), style: .default) { _ in
                self.dataStore.failedPasscodeUnlockAttempts += 1
                handleValidationFailure()
                
            }
            //Display a message.
            _ = KeyWindowAlert(title: "WARNING", message: "Your password has already been changed and you are still using the old one.\nPlease enter the new correct one.", actions: [alertAction]).show()

        case (.authenticationFailed, .wrongPasscode): fallthrough
        case (.authenticationFailed, .maxFailedAttemptsMade):
            handleValidationFailure()
        }
    }

    private func updateAuthenticatedPasscode(passcode: String) {
        
        //EscrowedKeyFetchOperation always needs identity (common or application) to fetchkey
        let escrowKeyFetchOperation = EscrowedKeyFetchOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        
        guard let identity = self.identity else {
            log(error: "error in setting up identity")
            self.markOperationFailed()
            return
        }
        escrowKeyFetchOperation.identity = identity
        escrowKeyFetchOperation.completionBlock = { [ weak self] in
            
            guard let weakSelf = self else {
                log(error: "validate user credential failed as new password was not applied")
                return
            }
            var successfullRemovedPasscode = false
            
            if escrowKeyFetchOperation.operationCompletedSuccessfully == false {
                log(error: "Failed to get Escrow Key. Escrow operation failed. Will reset locally. Data will be gone!!!")
                successfullRemovedPasscode = false
            }
            
            let application = UIApplication.shared
            var bgTask: UIBackgroundTaskIdentifier = 0
            bgTask = application.beginBackgroundTask{ [weak application] in
                application?.endBackgroundTask(bgTask)
                bgTask = UIBackgroundTaskInvalid
            }
            
            //fetched cryptkey could be nil if we never got a chance to escrow previously
            
            if let fetchedCryptkey = escrowKeyFetchOperation.fetchedCryptKey {
                successfullRemovedPasscode = weakSelf.dataStore.removePasscode(key: ManagedKey.cryptKey(fetchedCryptkey))
                log(info: "removed passcode with fetched cryptkey: \(successfullRemovedPasscode)")
            }
            else {
                log(warning: "could not found any crypt key from escrow")
                successfullRemovedPasscode = false
            }
            
            if successfullRemovedPasscode == false {
                //TODO: Since user might knew about previous password. we might give another try asking user to enter old username and password. 
                // This will save user data, in case of key never escrowed. Offline/No network use cases.
                log(warning: "resetting store due to escrow failed while trying to silently update username password key. this will cause data loss")
                _ = weakSelf.dataStore.resetCurrentKey()
            }
            
            guard weakSelf.createDataStorePasscode(passcode, method: AWSDK.AuthenticationMethod.usernamePassword)
                else {
                log(error: "Failed to create a new passcode.")
                application.endBackgroundTask(bgTask)
                weakSelf.markOperationFailed()
                return
            }
            application.endBackgroundTask(bgTask)
            
            weakSelf.saveIdentity(identity: identity)
            weakSelf.handleUnlockSuccessful(unlockType: .usernamePassword)
        }
        
        SDKOperationQueue.workerQueue.addOperations([escrowKeyFetchOperation], waitUntilFinished: true)
    }
    
    internal func saveIdentity(identity: Identity?) {
        
        guard let identity = identity else {
            log(error: "error in setting up identity")
            self.markOperationFailed()
            return
        }
        
        guard self.username.characters.count > 0,
            self.password.characters.count > 0 else {
            log(error: "error in setting up account")
            self.markOperationFailed()
            return
        }

        let enrollmentAccount = AWEnrollmentAccount(activationCode: self.authenticatorConfig?.organizationGroup, username: self.username, password: self.password)
        self.dataStore.enrollmentAccount = enrollmentAccount
        
        if self.requiredIdentityType == .common {
            self.dataStore.commonIdentity = identity
        } else {
            self.dataStore.applicationIdentity = identity
        }
       
    }

}
