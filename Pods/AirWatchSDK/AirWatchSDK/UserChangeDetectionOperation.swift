//
//  UserChangeDetectionOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWServices
import AWLocalization

internal class UserChangeDetectionOperation: SDKSetupAsyncOperation {
    private var currentUserInfo: UserInformation? = nil

    override func startOperation() {
        self.currentUserInfo = self.dataStore.currentUserInformation

        guard self.dataStore.applicationIdentity?.authorization != nil else {
            log(info: "Can not detect user change when user is not authenticated.")
            self.markOperationComplete()
            return
        }

        let deviceServices = self.dataStore.deviceServices
        deviceServices?.fetchEnrolledUserInformation {[weak self] (userinfo, error) in
            if let error = error {
                log(error: "Error Fetching user information: \(error)")
            }

            if let userinformation =  userinfo {
                self?.updateUserInformation(updatedInfo: userinformation._UserInformation)
            } else {
                log(error: "Missing User Information. Will not check user change")
            }
            self?.markOperationComplete()
        }
    }

    private func updateUserInformation(updatedInfo: UserInformation) {
        if let currentUserInfo = self.currentUserInfo, updatedInfo != currentUserInfo {
            log(warning: "Detected user change. Make sure we wipe application information before continue")
            self.dataStore.currentUserInformation = updatedInfo
            DispatchQueue.main.async {
                self.sdkController.delegate?.controllerDidDetectUserChange?()
            }
            
            //Reset previous user application settings
            log(info: "Wiping previous application settings")
            _ = self.dataStore.resetPreviousUserApplicationSettings()
            self.sdkController.start()

        } else {
            self.dataStore.currentUserInformation = updatedInfo
            log(warning: "Current user is same as logged in user.")
        }
    }
}
