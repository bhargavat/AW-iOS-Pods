//
//  AuthenticationPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import AWError
import AWPresentation
import Foundation

internal class AuthenticationPolicyEnforcer: PolicyEnforcementOperation {

    override var payloadType: String { return AuthenticationPayload.type }
    private struct AuthenticationSingleSignOnStatus {
        let status: AWSDK.SSOStatus
        let udpated: Bool
    }
    private var singleSignOnStatus = AuthenticationSingleSignOnStatus(status: .unknown, udpated: false)
    private var authenticationPayload: AuthenticationPayload? {

        // if singlesignonEnabled compare timeStamps between stored and savedprofile, use payload from latest
        guard self.dataStore.enabledSingleSignOn else {
            return self.profile?.getPayload(self.payloadType)
        }

        guard let authPayloadfromKeychain = self.dataStore.appliedAuthenticationPayload else {
            log(info: "no auth payload found in keychain")
            return self.profile?.getPayload(self.payloadType)
        }

        guard let authpayloadInSavedProfile = self.profile?.getPayload(self.payloadType) as? AuthenticationPayload else {
            log(info: "auth payload not found in saved profile, using auth payloadfrom keychain")
            return authPayloadfromKeychain
        }

        guard  let timeStampFromProfile =  self.profile?.timeStamp else {
            log(error: "timeStamp not found for auth payload in saved profile, using auth payloadfrom keychain")
            return authPayloadfromKeychain
        }



        guard let timeStampForAuthPayloadFromKeychain = self.dataStore.appliedAuthenticationPayloadTimestamp else {
            log(error: "timeStamp not found for auth payload in keychain, using auth payloadfrom from saved profile")
            return authpayloadInSavedProfile
        }

        guard timeStampFromProfile > timeStampForAuthPayloadFromKeychain else {
            log(info: "auth payload from keychain is latest, using auth payload from keychain")
            return authPayloadfromKeychain
        }

        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {

        guard let payload = self.authenticationPayload else {
            log(error: "No payload present. Completing enforcement")
            self.enforcementComplete()
            return
        }

        guard self.dataStore.applicationIdentity?.authorization != nil else {
            log(error: "📌📌Application Identity was not setup. Can not apply Authentication Policy now.📌📌")
            self.enforcementComplete()
            return
        }
        

        if self.dataStore.isNonSharedToSharedMigrationInProgress
            || (self.dataStore.enabledSingleSignOn != payload.enableSingleSignOn) {
            log(warning: "❕❗️❕❗️Data Store Single Sign On Status Will change to \(payload.enableSingleSignOn ? "Enabled" : "Disabled")❕❗️❕❗️")
            log(debug: "Saving SSO status to datastore as \(payload.enableSingleSignOn)")

            self.dataStore.isNonSharedToSharedMigrationInProgress = false
            self.dataStore.enabledSingleSignOn = payload.enableSingleSignOn
            
            let operation: SDKAccessControlSetupOperation = self.createOperation()
            SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
            self.dataStore.isNonSharedToSharedMigrationInProgress = false
            
            self.singleSignOnStatus = AuthenticationSingleSignOnStatus(status: payload.enableSingleSignOn ? .enabled : .disabled, udpated: true)
        } else {
            log(debug: "No need to save SSO status to datastore because it hasn't changed. Previous value: \(payload.enableSingleSignOn)")
            self.singleSignOnStatus = AuthenticationSingleSignOnStatus(status: self.dataStore.enabledSingleSignOn ? .enabled : .disabled, udpated: false)
        }

        let requiredAuthenticationMethod = payload.authenticationMethod
        // TODO: Remove these lines when we do not need to support pre 6.0 SDK
        // Explanation: In pre 6.0 authenticationMethod is not set when the user goes from Passcode to Disabled or from UsernamePassword to Disabled. But when the user does go from Passcode to Disabled or from UsernamePassword to Disabled, then isPasscodeSet becomes false.
        let isPasscodeSet = self.dataStore.isPasscodeSet
        if isPasscodeSet == false {
            self.dataStore.currentAuthenticationMethod = .none
        }
        let currentAuthenticationMethod = self.dataStore.currentAuthenticationMethod

        log(debug: "Current Data store Authentication Method: \(currentAuthenticationMethod)")
        log(debug: "Targeted Authentication Method: \(requiredAuthenticationMethod)")

        guard requiredAuthenticationMethod != currentAuthenticationMethod else {
            self.syncAppliedAuthenticationPayloadAndCompleteOperation()
            return
        }

        self.setupAuthentication(method: requiredAuthenticationMethod)
    }

    private func setupAuthentication(method: AWSDK.AuthenticationMethod) {

        // if authenticationMethod differs from what is currently saved to what the payload says, then we need
        // to figure how to update the passcode with some value or add a default value if no passcode is requested.
        // A passcode can be combining UsernamePassword to save as a passcode or the passcode can be the user's input for creating a passcode.
#if sdk_mixpanel_data_collection_enabled
        let changedAuthenticationMethodEvent = SDKSettings.authentication("\(method)")
        SDKMixpanelDataCollectionService.sharedInstance?.track(event: changedAuthenticationMethodEvent)
#endif
        switch method {
        case .passcode:
            updateDataStoreToPasscodeAuthenticationMode()

        case .usernamePassword:
            updateDataStoreToUsernamePasswordAuthenticationMode()

        case .none:
            updateDataStoreToDisabledAuthenticationMode()
        }
    }

    private func updateDataStoreToDisabledAuthenticationMode() {
        let currentAuthenticationMethod = self.dataStore.currentAuthenticationMethod
        guard self.dataStore.isPasscodeSet else {
            log(debug: "No Passcode is set. No need to take any action.")
            self.syncAppliedAuthenticationPayloadAndCompleteOperation()
            return
        }

        // If the new authenticationMethod is Disabled, then we need to see if a passcode was set to either replace it with a default passcode
        log(debug: "An authentication method (\(currentAuthenticationMethod)) was set and will be removed.")

        self.removeCurrentPasscode { (error: Error?) in
            self.enforcementComplete(error)
        }

    }
    
    private func updateDataStoreToPasscodeAuthenticationMode() {
        let currentAuthenticationMethod = self.dataStore.currentAuthenticationMethod
        // If the new authenticationMethod is passcode, we need to figure out the appropriate action to take based off of the previous authenticationMethod
        log(debug: "The new authentication method (Passcode) in the payload does not match the saved \(currentAuthenticationMethod)")
        
        guard self.dataStore.isPasscodeSet else {
            // no passcode was set previously because the authenticationMethod was .None,
            // let's create a passcode by using UsernamePassword or Passcode by what the payload says.
            log(debug: "No passcode was set, but a required passcode must be entered by user")
            self.secureDataStore(using: .passcode)
            return
        }
        
        guard currentAuthenticationMethod == .usernamePassword else {
            log(error: "Unknown passcode mode. We dont know how to update security from mode(\(currentAuthenticationMethod)) to passcode")
            return
        }
        
        log(debug: "Since a passcode is set, we need to drop it to change to username and password")
        self.removeCurrentPasscode { (error: Error?) in
            guard error == nil else {
                log(debug: "Could not remove the current passcode")
                self.enforcementComplete(error)
                return
            }
            self.secureDataStore(using: .passcode)
        }
    }
    
    private func updateDataStoreToUsernamePasswordAuthenticationMode() {
        let currentAuthenticationMethod = self.dataStore.currentAuthenticationMethod
        // If the new authenticationMethod is UsernamePassword, we need to remove the old passcode and create a new passcode using UsernamePassword and escrow
        log(debug: "The new authentication method (UsernamePassword) in the payload does not match the saved value \(currentAuthenticationMethod)")
        
        guard self.dataStore.isPasscodeSet else {
            // no passcode was set previously because the authenticationMethod was .None,
            // let's create a passcode by using UsernamePassword or Passcode by what the payload says.
            log(debug: "No passcode was set, but we should create a passcode based on username and password")
            self.secureDataStore(using: .usernamePassword)
            return
        }
        
        guard currentAuthenticationMethod == .passcode else {
            log(error: "Unknown passcode mode. We dont know how to update security from current mode (\(currentAuthenticationMethod)) to username/password")
            return
        }
        
        self.removeCurrentPasscode { (error: Error?) in
            if error == nil {
                self.secureDataStore(using: .usernamePassword)
                return
            }
            self.enforcementComplete(error)
        }
    }
    
    func removeCurrentPasscode(_ completion: @escaping (_ error: Error?) -> Void) {
        if let applicationDataStore = self.dataStore as? ApplicationDataStore,
            let sessionManager = applicationDataStore.sessionManager {
            log(debug: "Will attempt to remove lock from store using the session key from store.")
            if let sessionKey = sessionManager.sessionKey() {
                let didRemovePasscode = self.dataStore.removePasscode(key: .sessionKey(sessionKey))
                if didRemovePasscode {
                    log(debug: "Lock removed from store")
                    completion(nil)
                    return
                } else {
                    log(debug: "Could not remove lock from store locally. Will attempt to use fetch escrowed key.")
                }
            }
            //debug or error , depends on the flow
            log(debug: "Could not retrieve cryptKey to remove the passcode")
        }

        let escrowKeyFetchOperation = EscrowedKeyFetchOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)

        escrowKeyFetchOperation.completionBlock = {[weak self, weak escrowKeyFetchOperation] in
            guard let fetchOperation = escrowKeyFetchOperation,
                let enforcer = self else {
                return
            }

            guard fetchOperation.operationCompletedSuccessfully else {
                completion(AWError.SDK.Policy.Enforcement.Authentication.escrowedPasscodeRetrievalFailed)
                return
            }

            if let escrowedCryptKey = escrowKeyFetchOperation?.fetchedCryptKey {
                if enforcer.dataStore.removePasscode(key: .cryptKey(escrowedCryptKey)) {
                    log(debug: "Lock removed from store using escrow 🙂")
                    completion(nil)
                    return
                }
                log(debug: "☛ Can not drop the passcode using the key. 🤔")
                completion(AWError.SDK.Policy.Enforcement.Authentication.failedToRemovePasscode)
                return
            }

            let error = escrowKeyFetchOperation?.error ?? AWError.SDK.Policy.Enforcement.Authentication.escrowedPasscodeRetrievalFailed
            log(debug: "Did not get the Crypt Key to clear passcode. Error: \(error)")
            self?.enforcementComplete(error)
            return
        }

        SDKOperationQueue.workerQueue.addOperations([escrowKeyFetchOperation], waitUntilFinished: false)
    }
    
    private func secureDataStore(using authenticationMethod: AWSDK.AuthenticationMethod) {
        let operation: SDKSetupAsyncOperation
        if authenticationMethod == .passcode {
            log(debug: "Will need to create a passcode using input from the user")
            operation = CreatePasscodeOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        } else if authenticationMethod == .usernamePassword {
            log(debug: "Will need to create a passcode using username and password")
            operation = CreatePasscodeWithUserCredentialsOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        } else {
            log(error: "Unknown method for passcode creation")
            return
        }

        operation.completionBlock = {[weak self, weak operation] in
            guard let successful: Bool = operation?.operationCompletedSuccessfully else {
                log(error: "Parent operation is not alive to report Create Passcode failure.")
                return
            }
            if successful {
                self?.syncAppliedAuthenticationPayloadAndCompleteOperation()
            } else {
                self?.enforcementComplete(AWError.SDK.Policy.Enforcement.Authentication.failedToCreatePasscode)
            }
        }

        SDKOperationQueue.workerQueue.addOperation(operation)
    }

    func syncAppliedAuthenticationPayloadAndCompleteOperation() {
        self.dataStore.appliedAuthenticationPayload = self.authenticationPayload
        self.enforcementComplete()
    }


}


extension AbstractDataStoreItemLoader {

    var appliedAuthenticationPayloadTimestamp: TimeInterval? {
        return self.commonDataStore.getlastUpdatedTimestamp(itemQueryProvider.AuthenticationPayload.group, key: itemQueryProvider.AuthenticationPayload.key)
    }

}
