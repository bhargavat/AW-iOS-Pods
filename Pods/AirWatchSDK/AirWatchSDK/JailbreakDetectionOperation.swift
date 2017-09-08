//
//  File.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
/**
 Check to see if the device is jailbroken
 */
class JailbreakDetectionOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        let enrollmentInformation: EnrollmentInformation? = self.dataStore.enrollmentInformation
        let jailBreakStatusInProfile = self.dataStore.SDKProfile?.compliancePayload?.enableCompromisedProtection
        
        guard
            enrollmentInformation != nil,
            jailBreakStatusInProfile == true,
            awIsCompromised()
        else {
            self.markOperationComplete()
            return
        }
        
        // if the user has not specified enrollment information then we shouldn't check if the device is compromised
        // now if the user has entered server information and the device is compromised, then let's lock the device and alert console the device is jailbroken
        self.presenter.displayJailbroken()
        self.sdkController.setupEncounteredFailure(error: .deviceIsCompromised)
        SDKBeaconTransmitter.sharedTransmitter.sendDeviceStatusBeacon { (success, error) in
            log(info: "beacon sent for compromised device: \(success) with error \(String(describing: error))")
        }
        log(error: "Device is detected as compromised !!!! ")
        let currentUserLogoutOperation: CurrentUserLogoutOperation = self.createOperation()
        currentUserLogoutOperation.completionBlock = { [weak self] in
            self?.markOperationFailed()
        }
        SDKOperationQueue.workerQueue.addOperations([currentUserLogoutOperation], waitUntilFinished: true)
    }
}
