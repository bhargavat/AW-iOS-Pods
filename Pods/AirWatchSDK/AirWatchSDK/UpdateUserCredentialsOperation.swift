//
//  UpdateUserCredentialsOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//
//

import Foundation
import AWHelpers

internal class UpdateUserCredentialsOperation: CredentialsAuthenticationOperation {

    internal var username:String? = nil
    
    override func startOperation() {

        let requiredIdentityType = self.dataStore.profileRequiredSingleSignOn ? IdentityType.common : IdentityType.application
        self.requiredIdentityType = requiredIdentityType
        
        guard Reachability.forInternetConnection?.currentReachabilityStatus != .notReachable else {
            _ = KeyWindowAlert(title: "Error", message: "You need an active internet to update the user credentials.").show()
            self.markOperationFailed()
            return
        }

        guard let username = self.dataStore.enrollmentAccount?.username else {
            log(error: "This operation can only be executed on condition of an existing account. Please setup an enrollment account before using this operation.")
            self.markOperationFailed()
            return
        }

        self.username = username
        super.startOperation()
    }
    
    override func performAuthentication() {
        let options = AuthenticationOptions.updateUserCredentialOptions
        self.presenter.presentAuthentication(options: options, touchIDOptions: .none, delegate: self)
    }
    
    override func login(username: String, password: String, rememberUser: Bool, workOffline: Bool, completionHandler: @escaping (Bool) -> Void ) {
        
        //we need to make sure only password is changed
        guard self.username == username else {
            _ = KeyWindowAlert(title: "Error", message: "You can only update the credentials for the current user rather than switching to another user.").show()
            completionHandler(false)
            return
        }
        super.login(username: username, password: password, rememberUser: rememberUser, workOffline: workOffline, completionHandler: completionHandler)
        }
    
    override func identitySetupComplete() {
        
        //authentication from the server must be success at this point
        guard let identity = self.identity else {
            log(error: "error in setting up identity")
            self.markOperationFailed()
            return
        }
        
        guard let account = self.account else {
            log(error: "error in setting up account")
            self.markOperationFailed()
            return
        }
        
        self.dataStore.enrollmentAccount = account
        if self.requiredIdentityType == .common {
            self.dataStore.commonIdentity = identity
        } else {
            self.dataStore.applicationIdentity = identity
        }
        self.markOperationComplete()
    }
    
}

    /*

    // According to the browser team, they expect to show the cancel button
    internal override func authenticateWithUsernameAndPassword() {
        self.presenter.pushAuthenticationUsernamePassword(delegate: self,
                                                          showRememberUsername: false,
                                                          showWorkOffline: false,
                                                          showToken: false,
                                                          showTouchID: false,
                                                          showCancel: true)
    }
    
    override func login(username: String, password: String, rememberUser: Bool, workOffline: Bool, completionHandler: @escaping ((Bool) -> Void)) {
        guard self.username == username else {
            _ = KeyWindowAlert(title: "Error", message: "You can only update the credentials for the current user rather than switching to another user.").show()
            completionHandler(false)
            return
        }
        super.login(username: username, password: password, rememberUser: rememberUser, workOffline: workOffline, completionHandler: completionHandler)
    }

    internal override func cancelViewController() {
        self.markOperationFailed()
        super.cancelViewController()
    }

    internal override func useIdentity(_ identity: Identity, account: AWEnrollmentAccount?) {
        super.useIdentity(identity, account: account)
        self.presenter.dismissNonBlockingViewControllers()
        self.markOperationComplete()
    }
 */

