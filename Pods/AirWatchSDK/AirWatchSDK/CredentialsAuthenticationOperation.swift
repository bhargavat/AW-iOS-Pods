//
//  CredentialsAuthenticationOperation.swift
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
import AWError
import AWLocalization
import AWPresentation


extension AWError.SDK {

    public enum CredentialsAuthentication: AWErrorType {
        case missingRequiredCredentials
        case badUsernameOrPassword
        case cannotVerifyToken
        case userCancelledAuthentication
    }
}

class CredentialsAuthenticationOperation: TokenAuthenticationOperation, AuthenticationViewControllerDelegate {

    var authenticationOptions = AuthenticationOptions.identitySetupOptions

    internal override func performAuthentication() {
        self.performCredentialsAuthentication()
    }

    internal func performCredentialsAuthentication() {
        self.presenter.presentAuthentication(options: self.authenticationOptions, touchIDOptions: TouchIDOptions.none, delegate: self)
    }

    internal func authenticationFailed(error: NSError?) {
        let localizableInfo = error?.userInfo[NSLocalizedDescriptionKey] as? String ?? "UnknownErrorMessage"
        _ = KeyWindowAlert(title: "Error", message: localizableInfo.localized).show()
    }

    func login(username: String, password: String, rememberUser: Bool, workOffline: Bool, completionHandler: @escaping (Bool) -> Void ) {
        //Remember User and Work Offline will never be used in this context 
        guard
            let config = self.authenticatorConfig,
            let authentication = try? UserRemoteAuthentication(configValues: config)
        else {
            completionHandler(false)
            return
        }

        _ = try? authentication.authenticateUserToRetrieveHMAC(UserName: username,
                                                               Password: password) { (response, error) in
            guard let hmacToken = response?.token.hmacToken, error == nil else {
                log(error: "Failed to authenticate user.")
                //if error is network error? prompt with failure
                self.authenticationFailed(error: error)
                self.identitySetupError = AWError.SDK.CredentialsAuthentication.badUsernameOrPassword
                self.identity = nil
                completionHandler(false)
                return
            }
            let enrollmentAccount = AWEnrollmentAccount(activationCode: self.authenticatorConfig?.organizationGroup, username: username, password: password)
            log(debug: "HMAC Received for \(self.requiredIdentityType): \(hmacToken)")
            self.dataStore.username = username
            self.createIdentity(hmacToken: hmacToken, account: enrollmentAccount)
            completionHandler(true)

        }
    }

    override func identitySetupComplete() {
        self.markOperationComplete()
    }

    func unlockWithTouchID(completionHandler: @escaping (TouchIDResult) -> Void) {
        log(error: "Local Authentication is Not Supported while authetnicating the user.")
        //This should be handled only when unlocking
    }

    func login(authenticationToken: String, completionHandler: @escaping ((Bool)->Void)) {
        let showInvalidtokenAlert = {
            let warningTitle = AWSDKLocalization.getLocalizationString("Warning")
            let warningMessage = AWSDKLocalization.getLocalizationString("InvalidTokenError")
            _ = KeyWindowAlert(title: warningTitle, message: warningMessage).show()
        }

        if authenticationToken.characters.count == 0 {
            showInvalidtokenAlert()
            completionHandler(false)
            return
        }

        self.authenticate(token: authenticationToken) { (hmacToken, error) in

            guard let hmacToken = hmacToken, error == nil else {
                log(error: "Can not login user with Authtencation token. Failed to authenticate to retrieve HMAC. Error: \(error.debugDescription)")
                //if error is network error? prompt with failure
                self.identitySetupError = AWError.SDK.TokenAuthentication.cannotVerifyToken
                self.account = nil
                self.identity = nil
                showInvalidtokenAlert()
                completionHandler(false)
                return
            }

            let enrollmentAccount = AWEnrollmentAccount(activationCode: self.dataStore.enrollmentInformation?.organizationGroup,
                                                        authorizationToken: authenticationToken)
            log(debug: "Token HMAC Received: \(hmacToken)")
            self.createIdentity(hmacToken: hmacToken, account: enrollmentAccount)
        }
    }

    func rememberedUsernameToAutofill() -> String? { return self.dataStore.username }

    public func cancelViewController() {
        log(error: "Authtencation is cancelled by the User.")
        self.identity = nil
        self.account = nil
        self.identitySetupError = AWError.SDK.CredentialsAuthentication.userCancelledAuthentication
        self.markOperationFailed()
        self.presenter.pop()
    }

    public func showServerDetails() {
        log(error: "Displayng Server Details are not supported in simplified enrollment applications")
    }
}

class ExistingCredentialsAuthenticationOperation: CredentialsAuthenticationOperation {

    override func performAuthentication() {
        guard let account = self.account,
            account.username.characters.count > 0,
            account.password.characters.count > 0  else {
                log(error: "Provided username and password can not be used for silent login")
                self.markOperationFailed()
                return
        }

        log(info: "Logging in with provided credentials.")
        self.login(username: account.username, password: account.password, rememberUser: false, workOffline: false) { (success) in
            guard success else {
                log(error: "Provided Invalid credentials")
                self.account = nil
                let action = UIAlertAction(title: "OK", style: .default) { (action) in
                    self.markOperationFailed()
                }
                _ = KeyWindowAlert(title: "Error", message: AWSDKLocalizedString("DeviceMismatchErrorMessage"), actions: [action]).show()
                return
            }

            log(error: "Authentication using provided credentials")
            self.markOperationComplete()
        }
    }
    
    override func authenticationFailed(error: NSError?) {
        log(info: "existing credentials failed to authenticate the user")
    }
}
