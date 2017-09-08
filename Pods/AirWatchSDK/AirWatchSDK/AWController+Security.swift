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

extension AWError.SDK {
    public enum LogoutCurrentUserFailed: AWErrorType {
        case serverNotReachable
        case failedToReportUnenrollmentStatus
        case internalError
    }
}

extension AWController {

    public func canLockSession() -> Bool {
        return self.context.isPasscodeSet
    }

    // Lock the session manually. Internally other options are avialable for command, timeout, etc.
    public func lockSession() -> Bool{
        return self.lockSession(lockType: .manual)
    }

    // Specify the LockType will not affect how lock occurs. Internally we keep track of the lock type to know which is most common.
    internal func lockSession(lockType: LockType = .manual) -> Bool {

        guard let currentStore = self.context as? ApplicationDataStore else {
            log(error: "Current Store is not Application Data Store. Can not confirm lock")
            return false
        }

        _ = currentStore.lockCurrentStores(lockType: lockType)

        self.refreshSDK()
        return true
    }

    //This method wipes and reports unenrollment. Retruns error if internet is not available or unenrollment is not reported
    public func logoutCurrentUser(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        
        NetworkConnectivityStatusManager.sharedInstance.refresh()
        guard let reachability = NetworkConnectivityStatusManager.sharedInstance.reachability else {
            log(error: "⚠️⚠️⚠️Reachabilty is nil, cannot determine connectivity status⚠️⚠️⚠️")
            completion(false, AWError.SDK.LogoutCurrentUserFailed.internalError)
            return
        }
        if reachability.currentReachabilityStatus == .notReachable {
            log(error: "Cannot logout user as server is not reachable")
            completion(false, AWError.SDK.LogoutCurrentUserFailed.serverNotReachable)
            return
        }
        let controller = self
        let currentUserLogoutOperation = CurrentUserLogoutOperation(sdkController: self, presenter: self.presenter, dataStore: self.context)
        currentUserLogoutOperation.completionBlock = {
            var success = true
            var error: AWError.SDK.LogoutCurrentUserFailed? = nil
            if controller.context.shouldReportUnenrollment {
                success = false
                error = .failedToReportUnenrollmentStatus
            }
            completion(success, error)
        }
        SDKOperationQueue.workerQueue.addOperations([currentUserLogoutOperation], waitUntilFinished: false)
    }

}

