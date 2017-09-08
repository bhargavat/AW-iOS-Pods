//
//  AWEnrollmentAccount.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
extension AWSDK {
    // For backwards compatibility
    @objc (AWEnrollmentAuthenticationCredentials)
    public enum EnrollmentAuthenticationCredentialsType: Int {
        case none = 0
        case pin
        case usernamePassword
        case certificate
        case certificateWithPin
        case authorizationToken
        case sso
    }
}

@objc(AWEnrollmentAccount)
public final class AWEnrollmentAccount: NSObject {
    
    internal static let AWDefaultUserIdentifier = -1

    // Temporary for the sake of backwards compatibility
    public internal (set) var identifier: NSInteger = AWDefaultUserIdentifier
    public internal (set) var activationCode: String = ""
    public internal (set) var username: String = ""
    public internal (set) var password: String = ""
    public internal (set) var authorizationToken: String = ""
    public internal (set) var authenticationCredentialsType: AWSDK.EnrollmentAuthenticationCredentialsType = .none

    @available(*, unavailable, message: "Please use initWithActivationCode: ...")
    override init() {}

    @objc(initWithActivationCode:username:password:)
    public init(activationCode: String?, username: String?, password: String?) {
        authenticationCredentialsType = .usernamePassword
        if let activationCode = activationCode, let username = username, let password = password {
            self.activationCode = activationCode
            self.username = username
            self.password = password
            self.authenticationCredentialsType = .usernamePassword
        }

    }

    @objc(initWithActivationCode:authorizationToken:)
    public init(activationCode: String?, authorizationToken: String?) {
        authenticationCredentialsType = .authorizationToken
        if let activationCode = activationCode, let authorizationToken = authorizationToken {
            self.activationCode = activationCode
            self.authorizationToken = authorizationToken
            self.authenticationCredentialsType = .authorizationToken
        }
    }
    
    @objc
    public var isAccountAuthenticated: Bool {
        return self.identifier != AWEnrollmentAccount.AWDefaultUserIdentifier
    }

}

extension CoderKeys {
    class AWEnrollmentAccount {
        static let SSOLocationGroupKey = "AWSSOLocationGroup"
        static let SSOUsernameKey = "AWSSOUsername"
        static let SSOPasswordKey = "AWSSOPassword"
        static let SSOIdentifierKey = "AWSSOIdentifier"
        static let SSOCredentialsType = "AWSSOCredentialsType"
    }
}

extension AWEnrollmentAccount: DataRepresentable {
    public func toData() -> Data? {
        var params: [String: AnyObject] = [:]
        params[CoderKeys.AWEnrollmentAccount.SSOLocationGroupKey] = self.activationCode as AnyObject?
        params[CoderKeys.AWEnrollmentAccount.SSOUsernameKey] = self.username as AnyObject?
        params[CoderKeys.AWEnrollmentAccount.SSOPasswordKey] = self.password as AnyObject?
        params[CoderKeys.AWEnrollmentAccount.SSOIdentifierKey] = NSNumber(value: self.identifier as Int)
        params[CoderKeys.AWEnrollmentAccount.SSOCredentialsType] = NSNumber(value: self.authenticationCredentialsType.rawValue as Int)
        return (params as NSDictionary).toData()
    }

    public static func fromData(_ data: Data?) -> AWEnrollmentAccount? {
        if let dict = NSDictionary.fromData(data) as? [String: AnyObject] {
            let enrollmentAccount = AWEnrollmentAccount(activationCode: "", username: "", password: "")

            if let locationGroup = dict[CoderKeys.AWEnrollmentAccount.SSOLocationGroupKey] as? String {
                enrollmentAccount.activationCode = locationGroup
            }

            if let username = dict[CoderKeys.AWEnrollmentAccount.SSOUsernameKey] as? String {
                enrollmentAccount.username = username
            }

            if let password = dict[CoderKeys.AWEnrollmentAccount.SSOPasswordKey] as? String {
                enrollmentAccount.password = password
            }

            if let identifier = dict[CoderKeys.AWEnrollmentAccount.SSOIdentifierKey] as? NSNumber {
                enrollmentAccount.identifier = identifier.intValue
            } else {
                enrollmentAccount.identifier = -1
            }

            if let credentialsType = dict[CoderKeys.AWEnrollmentAccount.SSOCredentialsType] as? NSNumber {
                enrollmentAccount.authenticationCredentialsType = AWSDK.EnrollmentAuthenticationCredentialsType(rawValue: credentialsType.intValue) ?? .none
            } else {
                enrollmentAccount.identifier = -1
            }
            return enrollmentAccount
        }
        return nil
    }
}

