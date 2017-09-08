//
//  CheckPendingUnenrollmentReportOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWHelpers
import AWLocalization
import AWPresentation

class CheckPendingUnenrollmentReportOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        log(debug: "Checking wheter unenrollment should be reported to the server")
        
        guard self.dataStore.shouldReportUnenrollment else {
            log(info: "No need to report unenrollment moving on...")
            //remove blocker if we were showing before
            self.presenter.enable()
            self.markOperationComplete()
            return
        }

        log(error: "Should report unenrollment to the server.")

        // block the user right away with the loading screen and try to report unenrollment silently
        self.presenter.reset()
        self.presenter.disable()
        
        let currentUserLogoutOperation = CurrentUserLogoutOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore:self.dataStore)

        let awcontroller = self.sdkController
        let awpresenter = self.presenter

        currentUserLogoutOperation.completionBlock = { [weak self] in
            awpresenter.enable()
            // If we failed to report the unenrollment status to the server, we will fail the operation intentionally to exit early of the SDK setup workflow with initial check done error. The app will hanle it from there.
            guard self?.dataStore.shouldReportUnenrollment == false else {
                log(error: "CheckPendingUnenrollmentReportOperation operation failed, will stay in the loading screen and won't move forward")
                awpresenter.disable()
                awcontroller.setupEncounteredFailure(error: AWError.SDK.Setup.failedToReportUnenrollmentStatus)
                self?.markOperationFailed()
                return
            }

            self?.markOperationComplete()
        }

        SDKOperationQueue.workerQueue.addOperations([currentUserLogoutOperation], waitUntilFinished: true)
    }
}
