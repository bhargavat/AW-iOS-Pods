//
//  IdentitySetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWError
import AWLocalization
import AWPresentation

public enum IdentityType {

    case common
    case application

    public var authenticationGroup: String? {
        switch self {
        case .common:
            return AWAnchor.commonAuthenticationGroup
            
        case .application:
            return Bundle.main.bundleIdentifier
        }

    }
}

public extension AWError.SDK {
    public enum Authentication: AWErrorType {
        case BadUsernameOrPassword
    }
}

class IdentitySetupOperation: SDKSetupAsyncOperation {

    internal var requiredIdentityType = IdentityType.application

    internal var identity: Identity? = nil
    internal var identitySetupError: AWErrorType? = nil
    internal var account: AWEnrollmentAccount? = nil

    internal var authenticatorConfig: ConsoleServicesConfig? = nil
    internal var authenticationServices: UserRemoteAuthentication? = nil

    internal func setupAuthenticator() -> Bool {
        guard let authenticatorConfig = self.dataStore.consoleServicesConfig else {
            log(error: "Trying to setup Common Identity without Server Details. Showing Server Details")
            return false
        }

        guard
            let requestingAppBundleID = Bundle.main.bundleIdentifier,
            let authenticationGroup  = self.requiredIdentityType.authenticationGroup
            else {
                log(error: "Trying to setup Identity for an App with out Bundle ID.")
                return false
        }

        authenticatorConfig.authenticationGroup = authenticationGroup
        authenticatorConfig.requestingApp = requestingAppBundleID

        guard let authenticationServices = try? UserRemoteAuthentication(configValues: authenticatorConfig) else {
            log(error: "Invalid Information for Authentication Services.")
            return false
        }

        self.authenticatorConfig = authenticatorConfig
        self.authenticationServices = authenticationServices
        return true
    }

    override func startOperation() {
        guard self.setupAuthenticator() else {
            log(error: "Can not Authentication User, Failed.")
            self.markOperationFailed()
            return
        }

        guard
            self.authenticatorConfig != nil,
            self.authenticationServices != nil else {
                log(error: "Missing Required Information")
                self.markOperationFailed()
                return
        }

        self.performAuthentication()
    }

    func performAuthentication() {
        log(debug: "Should be overriden!")
        self.markOperationComplete()
    }

    internal func createIdentity(hmacToken: String, account: AWEnrollmentAccount?) {
        let enrollment = authenticatorConfig?.getEnrollmentInformation()

        enrollment?.lastKnownEnrollmentStatus = .enrolled
        enrollment?.lastVerifiedDate = Date()

        let authenticationInformation = AuthenticatonInfo()
        authenticationInformation.authorizationGroup = requiredIdentityType.authenticationGroup
        authenticationInformation.hmacToken = hmacToken
        log(info: "Created HMAC for authorization group: \(String(describing: authenticationInformation.authorizationGroup))")

        let identity = Identity()
        identity.enrollment = enrollment
        identity.authorization = authenticationInformation
        self.identity = identity
        self.account = account
        self.identitySetupError = nil
        self.identitySetupComplete()
    }

    func identitySetupComplete() {
        //Mark your operation complete here.
        log(debug: "Should be overriden!")
        self.markOperationComplete()
    }

}
