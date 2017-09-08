//
//  AWController+CommandHandler.swift
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

public extension AWController {

    public var dataStore: SDKDataStore { return context }

    public var account: AWEnrollmentAccount {
        if let account = self.context.enrollmentAccount {
            return account
        }
        return AWEnrollmentAccount(activationCode: "", username: "", password: "")
    }


    typealias UpdateUserCredentialsCompletionHandler = (_ success: Bool, _ error: Error?) -> ()

    public func updateUserCredentials(with completion: @escaping UpdateUserCredentialsCompletionHandler) -> () {

        let currentPresenter = self.presenter
        let updateUserCredentialsOperation = UpdateUserCredentialsOperation(sdkController: self, presenter: self.presenter, dataStore: self.context)

        updateUserCredentialsOperation.completionBlock = { [weak updateUserCredentialsOperation] in
            guard let operation = updateUserCredentialsOperation else {
                return
            }

            guard operation.operationCompletedSuccessfully else {
                completion(false, AWError.SDK.AuthenticationHandler.authenticationFailed)
                return
            }
            currentPresenter.dismissNonBlockingViewControllers()
            completion(true, nil)
        }

        SDKOperationQueue.workerQueue.addOperation(updateUserCredentialsOperation)
    }
}
