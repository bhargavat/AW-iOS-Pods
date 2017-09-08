//
//  CreatePasscodeOperation.swift
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

class CreatePasscodeOperation: SDKSetupAsyncOperation, AbstractDataStorePasscodeSetupOperation, CreatePasscodeViewControllerDelegate {
    let passcodeRestrictor: PasscodeCompliance

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        passcodeRestrictor = PasscodeCompliance(dataStore: dataStore)
        ///if this is a forgot passcode senario, this will check against the current passcode
        ///if there is no passcode set, this will have no affect
        passcodeRestrictor.checkHistoryRequirement = true
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }

    ///(1) Push SDKCreatePasscodeViewController
    override internal func startOperation() {
        guard let store = self.dataStore as? ApplicationDataStore else {
            log(error: "Invalid Store, cannot create passcode")
            self.markOperationFailed()
            return
        }
        let showSSOLabel = store.shared && AWAnchor.isCurrentApplicationAirWatchApplication
        self.presenter.pushCreatePasscode(delegate: self,
                                          restrictor: passcodeRestrictor,
                                          showCancel: false,
                                          showSSOLabel: showSSOLabel)
    }

    internal func createPasscode(new passcode: String?,
                                 confirm confirmPasscode: String?,
                                 completionHandler completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {

        guard passcode == confirmPasscode, let passcode = passcode else {
            completion(false, NSError(domain:"Passcode Does Not match Confirm Passcode", code:-1, userInfo:nil))
            return
        }

        let passcodeCreated = self.createDataStorePasscode(passcode, method: AWSDK.AuthenticationMethod.passcode)
        guard passcodeCreated else {
            completion(false, NSError(domain:"Passcode cannot be created", code:-1, userInfo:nil))
            return
        }
        passcodeRestrictor.addPasscodeToHistory(passcode: passcode)
        completion(true, nil)
    }

    // Tells the delegate that the view controller is finished
    // if successful, `success` would be `true`, `errorOpt` would be `nil`
    // if not,`success` would be `true`, `errorOpt` would be some NSError
    func createPasscodeViewControllerFinished(success: Bool, error errorOpt: NSError?) {
        if success {
            log(info: "Change Passcode was successful and now we will dismiss the view controller")
            log(info: "We need to update biometrics and escrow the passcode")
        } else {
            log(error: "Error changing password: \(String(describing: errorOpt))")
        }

        self.completeDataStorePasscodeSetupOperation(success, error: errorOpt)
    }
}
