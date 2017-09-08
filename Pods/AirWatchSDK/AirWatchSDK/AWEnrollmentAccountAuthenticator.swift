//
//  AWEnrollmentAccountAuthenticator.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import AWError
import UIKit


@available(*, deprecated: 17.3)
@objc
open class AWEnrollmentAccountAuthenticator: NSObject {

    var consoleServicesConfig: UserAuthConfig? = AWController.sharedInstance.context.consoleServicesConfig
    var AuthenticationServicesType = UserRemoteAuthentication.self

    public override init() {
        super.init()
    }



    @objc
    open func authenticateAccount(enrollmentAccount: AWEnrollmentAccount, completion:@escaping (_ autheticated: Bool, _ account: AWEnrollmentAccount, _ error: NSError?) -> Void) {

        guard let authenticatorConfig = consoleServicesConfig else {
            log(error: "Unable to get configuration for AWEnrollmentAccountAuthenticator")
            let error = AWError.SDK.Enrollment.AccountAuthenticator.consoleServicesConfigNotSet.error
            completion(false, enrollmentAccount, error)
            return
        }

        let authenticationServices: UserRemoteAuthentication

        do {
            authenticationServices = try AuthenticationServicesType.init(configValues: authenticatorConfig)

        } catch let error as NSError {
            log(error: "Invalid Information for Authentication Services.")
            completion(false, enrollmentAccount, error)
            return
        }

        let username = enrollmentAccount.username
        let password = enrollmentAccount.password

        do {
            try _ = authenticationServices.authenticateUserToRetrieveHMAC(UserName: username as String, Password: password as String) {
                (AuthToken: UserRemoteAuthResponse?, error: NSError?) -> Void in
                guard error == nil && AuthToken != nil else {
                    log(error: "Authentication Services responded with error when authenticating: \(error.debugDescription).")
                    completion(false, enrollmentAccount, error)
                    return
                }

                guard let idString = AuthToken?.userId, let id = Int(idString) else {
                    log(error: "Error getting the userId from UserRemoteAuthResponse.")
                    let error = AWError.SDK.Enrollment.AccountAuthenticator.cannotParseUserID.error
                    completion(false, enrollmentAccount, error)
                    return
                }
                // Set the new idntifier number
                enrollmentAccount.identifier = id

                completion(true, enrollmentAccount, nil)

            }
        } catch let error as NSError {
            log(error: "Authentication services failed to authenticate user.")
            completion(false, enrollmentAccount, error)
            return
        }


    }

}
