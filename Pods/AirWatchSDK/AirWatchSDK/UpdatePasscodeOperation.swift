//
//  UpdatePasscodeOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


import AWPresentation
import AWServices


class UpdatePasscodeOperation: CreatePasscodeOperation {
    internal var currentKey: ManagedKey? = nil

    override internal func startOperation() {
        
        guard let applicationDataStore = self.dataStore as? ApplicationDataStore
            else {
            log(error: "Invalid Store, cannot update passcode")
            self.markOperationFailed()
            return
        }

        if self.currentKey != nil {
            log(info: "We have a key to update passcode.")
            let showSSOLabel = applicationDataStore.shared && AWAnchor.isCurrentApplicationAirWatchApplication
            self.presenter.pushCreatePasscode(delegate: self,
                                              restrictor: passcodeRestrictor,
                                              showCancel: false,
                                              showSSOLabel: showSSOLabel)
            return
        }
        
        guard
            let cryptor = applicationDataStore.masterDataStore.cryptor,
            let masterKeyCryptor = cryptor as? MasterKeyCryptor
        else {
            log(error: "A Kye must be provides or Store must be unlocked with passcode in order to update to compliant passcode.")
            self.markOperationFailed()
            return
        }
        self.currentKey = masterKeyCryptor.decryptionKey
        let showSSOLabel = applicationDataStore.shared && AWAnchor.isCurrentApplicationAirWatchApplication
        self.presenter.pushCreatePasscode(delegate: self,
                                          restrictor: passcodeRestrictor,
                                          showCancel: false,
                                          showSSOLabel: showSSOLabel)
    }

    internal override func createPasscode(new passcode: String?, confirm confirmPasscode: String?, completionHandler completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {
        guard let passcode = passcode,  passcode == confirmPasscode else {
            completion(false, NSError(domain:"Passcode Does Not match Confirm Passcode", code:-1, userInfo:nil))
            return
        }

        guard let oldKey  = self.currentKey else {
            log(error: "Store must be unlocked and key must be available to change to compliant passcode")
            self.markOperationFailed()
            return
        }

        let application = UIApplication.shared
        var bgTask: UIBackgroundTaskIdentifier = 0
        bgTask = application.beginBackgroundTask { [weak application] in
            application?.endBackgroundTask(bgTask)
            log(debug: "Passcode change task Killed by the System")
            bgTask = UIBackgroundTaskInvalid
        }

        let successfullRemovedPasscode = self.dataStore.removePasscode(key: oldKey)
        let successfullyCreatedNewPasscode = self.createDataStorePasscode(passcode, method: AWSDK.AuthenticationMethod.passcode)

        guard successfullRemovedPasscode && successfullyCreatedNewPasscode else {
            completion(false, NSError(domain:"Passcode cannot be updated", code:-1, userInfo:nil))
            return
        }
        passcodeRestrictor.addPasscodeToHistory(passcode: passcode)
        completion(true, nil)
        application.endBackgroundTask(bgTask)
        log(debug: "Finished change passcode")
    }

}
