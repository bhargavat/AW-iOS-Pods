//
//  AWHMACInquirer.swift
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

@objc
public class AWHMACInquirer: NSObject {
    internal var authenticationServices: UserRemoteAuthentication? = nil
    internal var authenticatorConfig: ConsoleServicesConfig? = nil
    
    public static let sharedInquirer = AWHMACInquirer()
    
    override init() {
        let consoleServicesConfig = AWController.sharedInstance.context.profileRequiredSingleSignOn ? AWController.sharedInstance.context.commonConsoleServicesConfig : AWController.sharedInstance.context.consoleServicesConfig
        
        guard let authenticatorConfig = consoleServicesConfig else {
            log(error: "Trying to Authenticate without Server details? ")
            return
        }
        
        guard let authenticationServices = try? UserRemoteAuthentication(configValues: authenticatorConfig) else {
            log(error: "Invalid Information for Authentication Services. Marking operation as failed.")
            return
        }
        
        self.authenticatorConfig = authenticatorConfig
        self.authenticationServices = authenticationServices
    }
    
    private func showInvalidInputError() {
        let _ = KeyWindowAlert(title: "Error", message: AWSDKLocalization.getLocalizationString("InvalidCredentialsTitle")).show()
    }
    
    public func fetchHMACSilently(Username username: String, Password password: String) -> () {
        guard username.characters.count != 0,
            password.characters.count != 0 else {
                let _ = KeyWindowAlert(title: "Error", message: AWSDKLocalization.getLocalizationString("InvalidCredentialsTitle")).show()
                return
        }
        
        do {
            _=try authenticationServices?.authenticateUserToRetrieveHMAC(UserName: username, Password: password) {[weak self] (authToken, error) in
                let hmacToken = authToken?.token.hmacToken
                if error != nil || hmacToken == nil {
                    log(error: "Can not setup Core Identity \(String(describing: error))")
                    self?.showInvalidInputError()
                    return
                }
                
                let enrollmentAccount = AWEnrollmentAccount(activationCode: AWController.sharedInstance.context.enrollmentInformation?.organizationGroup,
                                                            username: username,
                                                            password: password)
                
                log(info: "Username & Password HMAC Received: \(hmacToken!)")
                self?.createIdentity(hmacToken: hmacToken!, account: enrollmentAccount)
            }
        } catch {
            log(error: "Can not login user. Showing bad input error")
            showInvalidInputError()
        }
    }
    
    func createIdentity(hmacToken: String, account: AWEnrollmentAccount?) {
        
        let enrollment = authenticatorConfig?.getEnrollmentInformation()
        enrollment?.lastKnownEnrollmentStatus = .enrolled
        enrollment?.lastVerifiedDate = Date()

        let authenticationInformation = AuthenticatonInfo()
        authenticationInformation.authorizationGroup = self.authenticatorConfig?.authenticationGroup
        authenticationInformation.hmacToken = hmacToken
        
        let identity = Identity()
        
        identity.enrollment = enrollment
        identity.authorization = authenticationInformation
        self.useIdentity(identity: identity, account: account)
    }
    
    func useIdentity(identity: Identity, account: AWEnrollmentAccount?) {
        if AWController.sharedInstance.context.profileRequiredSingleSignOn && identity.authorization?.authorizationGroup == IdentityType.common.authenticationGroup {
            AWController.sharedInstance.context.commonIdentity = identity
        } else {
            AWController.sharedInstance.context.applicationIdentity = identity
        }
    }
}
