//
//  EnrollmentInformationSetupOperation.swift
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
import AWPresentation

class EnrollmentStatusCheckOperation: SDKSetupAsyncOperation {
    var currentEnrollmentStatus = AWSDK.EnrollmentStatus.unknown
    var enrollmentVerificationError: AWSDKErrorType? = nil
    
    var enrollmentStatusCheckError: AWSDKErrorType? = nil
    var offlinePolicyCompliant: Bool = false

    fileprivate let controller: SDKEnrollmentController

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        self.controller = SDKEnrollmentController(presenter: presenter, context: dataStore)
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        self.controller.delegate = self
    }

    override func startOperation() {
        self.controller.verifyCurrentEnrollment()
    }

    override func finishOperation() {
        self.controller.delegate = nil
        super.finishOperation()
    }
}

extension EnrollmentStatusCheckOperation: EnrollmentControllerDelegate {

    func enrollmentInformationDidSetup(_ enrollment: EnrollmentInformation) {
        log(info: "Unexpected Enrollment information did setup ")
        self.markOperationComplete()
    }

    func enrollmentInformationSetupFailed(_ error: AWError.SDK.Enrollment.General) {
        log(info: "Unexpected Enrollment information did Fail")

#if sdk_mixpanel_data_collection_enabled
        SDKMixpanelDataCollectionService.sharedInstance?.track(event: SDKLifeCycleEvent.initialization(false, error.errorDescription))
#endif    
        self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.enrollmentInformationSetup)
        self.markOperationFailed()
    }

    func enrollmentCheckCompleted(_ status: AWSDK.EnrollmentStatus) {
        log(info: "Enrollment check completed: \(status)")
        self.currentEnrollmentStatus = status
        self.markOperationComplete()
    }

    // This operation should not stop you from moving forward with setup.
    // We will not display any message here because, if we have an existing status then we will continue using that.
    // We also should not treat this as failure because this would block the application being used offline, if allowed.
    /*
     _ = KeyWindowAlert(title: "Error", message: "Error Retrieving Enrollment Status: \(error)").show()
     self.presenter.dismissNonBlockingViewControllers()
     SDKMixpanelDataCollectionService.sharedInstance?.track(event: SDKLifeCycleEvent.initialization(false, error.errorDescription))
     self.sdkController.delegate?.initialCheckDone(Error: error.error)
     self.markOperationFailed()
     */
    func enrollmentCheckFailed(_ error: Error?) {
        log(error: "Could not verify enrollment status. Error: \(error.debugDescription)")
        self.enrollmentStatusCheckError = error as?  AWError.SDK.Enrollment.General
        log(error: "Will mark operation as complete and will verify if we can use existing status")        
        self.markOperationComplete()
    }

    func continueWithEnrollmentInformation(_ enrollment: EnrollmentInformation, status: AWSDK.EnrollmentStatus, controller: SDKServerDetailsController) {
        self.currentEnrollmentStatus = status
        self.markOperationComplete()
    }
}
