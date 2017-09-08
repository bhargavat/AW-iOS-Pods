//
//  CreateDeviceRecordOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

class CreateDeviceRecordOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        log(debug: "Creating device record by settings up common identity")
        let commonIdentitySetupOperation = CoreIdentitySetupOperation(sdkController: self.sdkController,
                                                                      presenter: self.presenter,
                                                                      dataStore: self.dataStore)
        commonIdentitySetupOperation.requiredIdentityType = .common
        
        SDKOperationQueue.workerQueue.addOperations([commonIdentitySetupOperation], waitUntilFinished: true)
        guard commonIdentitySetupOperation.operationCompletedSuccessfully else {
            log(debug: "Failed to Created Device Record. Error: \(String(describing: commonIdentitySetupOperation.identitySetupError))")
            self.markOperationFailed()
            return
        }

        log(debug: "Common Identity Setup complete: \(String(describing: commonIdentitySetupOperation.identity?.authorization))")
        self.dataStore.commonIdentity = commonIdentitySetupOperation.identity

        log(debug: "Going to store Enrollment Account: \(String(describing: commonIdentitySetupOperation.account))")
        self.dataStore.enrollmentAccount = commonIdentitySetupOperation.account

        self.markOperationComplete()
    }
}
