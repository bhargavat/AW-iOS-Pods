//
//  AWController+StartProcessCustomizations.swift
//  AirWatchSDK
//
//  Copyright © 2017 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWError

public protocol Authorizaion {
    var token: String { get }
    var group: String { get }
}

public protocol Discovery {
    var userEmail: String { get }
    var airWatchServerURL: String { get }
    var organizationGroup: String { get }
    var deviceId: String { get }
}

public protocol AWSDKInformation {
    var discoveredEnvironment: Discovery { get }
    var groupIdentity: Authorizaion? { get }
    var applicationIdentity: Authorizaion? { get }
    var singleSignOnEnabled: Bool { get }
}

internal extension AWError.SDK.Controller {
    internal enum Bootstrap: AWErrorType {
        case missingRequiredInformation
        case containerWasLocked
    }

}

internal protocol SDKBootstrapping: class {
    var context: SDKContext { get set }

    ///Method to return if the container is locked or not.
    func canAccessProtectedData() -> Bool

    ///Method to bootstrap SDK with information
    func bootstrapSDK(information: AWSDKInformation) throws

    //Method to start SDK process normally
    func start()
}

extension SDKBootstrapping {

    func bootstrapSDK(information: AWSDKInformation) throws {

        self.context.setContext(shared: information.singleSignOnEnabled)
        guard self.canAccessProtectedData() else {
            throw AWError.SDK.Controller.Bootstrap.containerWasLocked
        }

        let enrollmentInformation = EnrollmentInformation()
        enrollmentInformation.deviceIdentifier = information.discoveredEnvironment.deviceId
        enrollmentInformation.hostname = information.discoveredEnvironment.airWatchServerURL
        enrollmentInformation.organizationGroup = information.discoveredEnvironment.organizationGroup
        enrollmentInformation.lastKnownEnrollmentStatus = .enrolled
        enrollmentInformation.lastVerifiedDate = Date()
        self.context.enrollmentInformation = enrollmentInformation
        guard enrollmentInformation.isComplete else {
            throw AWError.SDK.Controller.Bootstrap.missingRequiredInformation
        }

        if let groupIdentity = information.groupIdentity {
            let cIdAuth = AuthenticatonInfo(authorizationGroup: groupIdentity.group, hmacToken: groupIdentity.token)
            let cid = Identity(authorization: cIdAuth, enrollment: enrollmentInformation)
            self.context.commonIdentity = cid
        }

        if let appIdentity = information.applicationIdentity {
            let aIdAuth = AuthenticatonInfo(authorizationGroup: appIdentity.group, hmacToken: appIdentity.token)
            let aid = Identity(authorization: aIdAuth, enrollment: enrollmentInformation)
            self.context.applicationIdentity = aid
        }

        self.context.enrolledUserEmailAddress = information.discoveredEnvironment.userEmail
        self.context.onboardedUser = self.context.enrolledUser
        self.start()
    }
}

extension AWController: SDKBootstrapping {

    private func itemExists(query: KeyValueStoreItemQuery) -> Bool {
        let keychainStore = AWKeychain()
        let data: Data? = keychainStore.fetch(query)
        return (data != nil)
    }

    public var wasEnrolled: Bool {
        guard let enrollmentInformation = self.context.enrollmentInformation else {
            return false
        }
        guard enrollmentInformation.isComplete else {
            return false
        }

        let commonIdentityExists = self.itemExists(query: self.context.itemQueryProvider.CommonIdentityAuthenticationInformation)
        let legacyCommonIdentityExists = self.itemExists(query: self.context.itemQueryProvider.CommonIdentityAuthenticationInformation)
        let applicationIdentityExists = self.itemExists(query: self.context.itemQueryProvider.NonSharedAppIdentityAuthorizationInformation)

        guard (commonIdentityExists || legacyCommonIdentityExists || applicationIdentityExists) else {
            return false
        }
        return true
    }

    public func start(information: AWSDKInformation) throws {
        try self.bootstrapSDK(information: information)
    }
}
