//
//  EnrollmentInformationSetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWError
import AWHelpers
import AWLocalization
import AWServices
import AWPresentation
import Foundation

class EnrollmentInformationVerificationOperation: SDKSetupAsyncOperation, OnboardingViewControllerDelegate  {
    private let controller: SDKEnrollmentController
    internal static var lastknownEnrollmentStatus = AWSDK.EnrollmentStatus.unknown
    internal static var lastEnrollmentStatusCheckTimeStamp: Date? = nil
    
    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        self.controller = SDKEnrollmentController(presenter: presenter, context: dataStore)
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
    }

    override func startOperation() {
        //Do we have enrollment information from previous run?
        if self.controller.isEnrollmentInformationAvaialble {
            //If so, check that the user is still enrolled.
            self.verifyEnrollmentStatus()
            return
        }

        //Application must be launching for the first time, or after a wipe (can be for any reason).
        //Anyway, let do our own cleanup to ensure no hiccups.
        log(error: "going to wipe airwatch data since we are starting fresh")
        ApplicationDataStore.wipeAirWatchData()
        self.populateEnvironmentInformation()
    }
    
    private func populateEnvironmentInformation() {

        //Is Current Application and AirWatch Signed Application?
        if AWAnchor.isCurrentApplicationAirWatchApplication {

            //This application has right to enroll user. So, start Enrollment process.
            self.createEnrollmentInformation()
            return
        }

        //Check if the current application can use anchor application to get enrollment Information?
        let (success, error) = self.sdkController.fetchEnvironmentInformationForThirdPartyApplication()
        if success {
            // Everything is good. We have opened an Anchor application using OpenURL. 
            // We have nothing to do except wait for the flip back with information.
            return
        }

        // This is not an AirWatch Application. Also, Anchor is not present on the device or not whitelisted to be launched.
        let testEnrollmentServerURL = SDKDefaultSettings.sharedSettings.testEnrollmentServerURL()
        let testEnrollmentOrgGroup = SDKDefaultSettings.sharedSettings.testEnrollmentOrganizationGroup()

        //ISDK-169750: Support for App Store Review Flow for third party applications.
        if  testEnrollmentServerURL != nil, testEnrollmentOrgGroup != nil {
            //Continue enrollment.
            self.createTestEnrollmentInformation()
            return
        }

        //ISDK-169750: Support for App Store Review Flow for third party applications.
        if let environmentInformationFetchError = error as? AWError.SDK.OpenURLRequestFailed {
            switch environmentInformationFetchError {
            case .FailedToFetchEnvironmentDetailsFromAirWatchApplication:
                self.sdkController.setupEncounteredFailure(error: .failedToFetchEnvironmentInformationFromAirWatchApplication)

            case .CallBackSchemeNotAssigned:
                self.sdkController.setupEncounteredFailure(error: .callBackSchemeNotConfigured)

            case .AirWatchApplicationSchemeNotWhitelisted:
                self.sdkController.setupEncounteredFailure(error: .airWatchApplicationSchemeNotWhitelisted)

            case .AirWatchApplicationNotInstalled:
                self.sdkController.setupEncounteredFailure(error: .anchorRequiredForThirdPartyApplictionBootstrap)

            default:
                //ISDK-169444 edge case when we are still expecting a response back from anchor app
                log(error: "could not fetch environment information")
            }
        }

        self.markOperationFailed()
    }
    
    private func verifyEnrollmentStatus() {
        
        //Make sure you limit enrollment checks every hour or on relauches.
        if EnrollmentInformationVerificationOperation.lastknownEnrollmentStatus == AWSDK.EnrollmentStatus.enrolled,
            let statusCheckTimeStamp = EnrollmentInformationVerificationOperation.lastEnrollmentStatusCheckTimeStamp,
            Date().timeIntervalSince(statusCheckTimeStamp) < (60 * 60) {
            log(info: "Verified Enrollment as enrolled in last check not going to do this until app is relaunced or after an hour since last check.")
            self.checkApplicationOnboardedStatus()
            return
        }
        
        let previousEnrollmentStatus = self.dataStore.enrollmentInformation?.lastKnownEnrollmentStatus ?? AWSDK.EnrollmentStatus.unknown

        log(info: "Will Verify Enrollment Status from Console")
        let statusCheckOperation = EnrollmentStatusCheckOperation(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        SDKOperationQueue.workerQueue.addOperations([statusCheckOperation], waitUntilFinished: true)

        EnrollmentInformationVerificationOperation.lastknownEnrollmentStatus = statusCheckOperation.currentEnrollmentStatus
        EnrollmentInformationVerificationOperation.lastEnrollmentStatusCheckTimeStamp = Date()
        let currentEnrollmentStatus = statusCheckOperation.currentEnrollmentStatus
        log(error: "Verfied Enrollment status: \(currentEnrollmentStatus)")
        log(error: "Last Known Enrollment status: \(previousEnrollmentStatus)")
        
        /// (.unknown, .unknown):            - offline and app was never enrolled
        /// (.unknown, unenrolled)           - offline and the device has been unenrolled from a previous run
        /// (.deviceNotFound, .unenrolled)   - if there was a call to unenrollUser(), then previous enrollment status will be unenrolled and console responded again with device not found
        /// (unenrolled, unenrolled)         - enroll the user
        /// (deviceNotFound, unenrolled)     - enroll the user

        switch (currentEnrollmentStatus, previousEnrollmentStatus) {
        case (.unknown,     .unknown):           fallthrough // offline and app was never enrolled
        case (.unknown,     .unenrolled):        fallthrough
        case (.unenrolled,  .unenrolled):        fallthrough
        case (.unenrolled,  .deviceNotFound):    fallthrough
        case (.unknown,     .deviceNotFound):    self.populateEnvironmentInformation()

        case (.unenrolled,      _): fallthrough
        case (.deviceNotFound,  _):

            if AWAnchor.isCurrentApplicationAirWatchApplication {
                self.unenrollUser()
                break
            }

            // We will ask for the user input before we unenroll as the unenrollment will flip to
            // AirWatch Application immediately thus giving user no chance of knowing why it has to flip.
            let action = UIAlertAction(title: AWSDKLocalizedString("Continue"), style: .default) {[weak self] (action) in
                // User needs to tap on continue unenrollment
                // Unenroll user wipes serverurl and udid as well for third party apps
                self?.unenrollUser()
            }
            _ = KeyWindowAlert(title: AWSDKLocalizedString("Notice"), message: AWSDKLocalizedString("NeedToUpdateYourEnvironmentInformation"), actions: [action]).show()

        case (.unknown, _):  fallthrough
        default:
            ///Check to see if app has been onboarded yet
            log(debug: "Nothing we need to do now, except check if this app has been onboarded")
            self.checkApplicationOnboardedStatus()
        }

        DispatchQueue.main.async {
            let status = AWSDK.EnrollmentStatus(rawValue: currentEnrollmentStatus.rawValue) ?? .unknown
            self.sdkController.delegate?.controllerDidReceive?(enrollmentStatus: status)
        }
    }
    
    func checkApplicationOnboardedStatus() {
        
        let appOnboardedUser: String? = self.dataStore.onboardedUser
        let enrolledEmailAddress: String? = self.dataStore.enrolledUserEmailAddress
        let enrolledUser: String? = self.dataStore.enrolledUser ///"ServerURL":"enrolledUserEmailAddress"
        
        log(debug: "Checking Application Onboarded Status")
        log(debug: "appOnboardedUser: \(String(describing: appOnboardedUser))")
        log(debug: "enrolledUser: \(String(describing: enrolledUser))")
        log(debug: "enrolledEmailAddress: \(String(describing: enrolledEmailAddress))")
        
        
        //Disable Sign-in Screen ISDK-169714
//        let appOnboardedUser: String? = self.dataStore.onboardedUser
//        let enrolledEmailAddress: String? = self.dataStore.enrolledUserEmailAddress
//        let enrolledUser: String? = self.dataStore.enrolledUser ///"ServerURL":"enrolledUserEmailAddress"
//        
//        if appOnboardedUser == nil || appOnboardedUser != enrolledUser { /// appliction has not been onboarded yet; show sign in screen
//            log(debug: "Application has not been onboarded yet, displaying sign in screen")
//            if enrolledEmailAddress == nil {
//                log(error: "enrolledEmailAddress from dataStore is nil; Going to display server URL instead")
//                presenter.displaySecondAppSignInScreen(delegate: self, emailAddress: self.dataStore.enrollmentInformation?.hostname)
//            } else {
//                presenter.displaySecondAppSignInScreen(delegate: self, emailAddress: enrolledEmailAddress)
//            }
//        } else {
//            log(debug: "Application has already been onboarded")
//            self.markOperationComplete()
//        }
        
        log(info: "appOnboardedUser is nil: \(appOnboardedUser == nil)")
        log(info: "enrolledUser is nil: \(enrolledUser == nil)")
        log(info: "enrolledEmailAddress is nil: \(enrolledEmailAddress == nil)")
        
        log(info: "assigning onboardedUser to enrolledUser")
        self.dataStore.onboardedUser = self.dataStore.enrolledUser
        self.markOperationComplete()
        
    }
    
    func onboardUser(onboardedSuccessfully: @escaping (Bool) -> Void) {
        log(debug: "Setting onboardedUser to enrolledUser: \(String(describing: self.dataStore.enrolledUser))")
        self.dataStore.onboardedUser = self.dataStore.enrolledUser
        
        // TODO: add logic if needed; currently placed to follow expectations by protocol/caller
        onboardedSuccessfully(true)
        
        self.markOperationComplete()
    }
    
    private func createEnrollmentInformation() {
        log(debug: "Will Create Server Details from the user")
        let enrollmentInfoSetupOperation = EnrollmentInformationSetupOperation(sdkController: self.sdkController,
                                                                               presenter: self.presenter,
                                                                               dataStore: self.dataStore)
        SDKOperationQueue.workerQueue.addOperations([enrollmentInfoSetupOperation], waitUntilFinished: true)
        
        guard enrollmentInfoSetupOperation.operationCompletedSuccessfully else {
            // no need to call setupEncounteredError(_:) since EnrollmentInformationSetupOperation will have called it
            // no need to call initial check done here because SDKSetupOperation will check the errors saved and call it
            self.markOperationFailed()
            return
        }
        self.enrollUser()
    }

    private func createTestEnrollmentInformation() {
        log(debug: "Will Create Server Details from the user(T)")
        let operation: ReviewEnrollmentInformationSetupOperation = self.createOperation()
        weak var verificationOperation = self
        operation.completionBlock = { [weak operation] in
            guard let op = operation, op.operationCompletedSuccessfully else {
                // no need to call setupEncounteredError(_:) since EnrollmentInformationSetupOperation will have called it
                // no need to call initial check done here because SDKSetupOperation will check the errors saved and call it
                verificationOperation?.markOperationFailed()
                return
            }

            verificationOperation?.enrollUser()
        }

        SDKOperationQueue.workerQueue.addOperation(operation)
    }

    private func enrollUser() {
        log(debug: "Will Enroll user to Setup Identities")
        ConfigurationProfilesSetupOperation.configurationFetchTimestamp  = 0
        ConfigurationProfilesSetupOperation.fetchedProfiles = []

        let operationSequenceTypes: [SDKSetupAsyncOperation.Type] = [   ConsoleVersionVerificationOperation.self,
                                                                        PinningCertificateFetchOperation.self,
                                                                        SDKAccessControlSetupOperation.self,
                                                                        CreateDeviceRecordOperation.self]
//                                                                     ConfigurationProfilesSetupOperation.self,
//                                                                     SDKAccessControlSetupOperation.self,
//                                                                     ApplicationIdentitySetupOperation.self,
//                                                                     ApplyNonAuthenticatedSettingsOperation.self,
//                                                                     ApplyAuthenticatedSettingsOperation.self]

        let opSequence = createDependencyChain(operationSequenceTypes, dataStore: self.dataStore)
        SDKOperationQueue.workerQueue.addOperations(opSequence, waitUntilFinished: true)

        if let lastOperation = opSequence.last, lastOperation.operationCompletedSuccessfully {
                self.dataStore = lastOperation.dataStore
                self.markOperationComplete()
                return
        }
        
        log(error: "User not enrolled because an operation has failed")
        // no need to call setupEncounteredError(_:) since an operation in operationSequenceTypes will have called it
        // no need to call initial check done here because SDKSetupOperation will check the errors saved and call it
        // Reasons for failing could be that secure channel server fails and 500 is received during operations (check-in, profile download, etc) fail.
        self.markOperationFailed()
    }

    private func unenrollUser() {
        log(debug: "Will Unenroll user due to current status is determined to be unenrolled.")
        
        // This is a private function that will only be used inside this class, which means the unenrollment is caused from server. Whether it is from an endpoint or an unenrollment command, the console is already aware of the unenrollment status. So, the property self.dataStore.shouldReportUnenrollment can be set to false here immediately even before the DataStoreCleanupOperation is executed. The value is set here to prevent the unnecessary unenrollment status report on the next launch, which is time consuming and will make the UI hang.
        self.dataStore.shouldReportUnenrollment = false
        log(debug: "Will not report unenrollment status to server on next lanuch for console was already aware of it.")
        
        let dataStoreCleanupOperation = DataStoreCleanupOperation(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        SDKOperationQueue.workerQueue.addOperations([dataStoreCleanupOperation], waitUntilFinished: true)
        ApplicationDataStore.wipeAirWatchData()
        // TODO: make this fail and restart the flow again.
        let enrollmentInformation = self.sdkController.context.enrollmentInformation ?? EnrollmentInformation()
        enrollmentInformation.lastKnownEnrollmentStatus = .unenrolled
        enrollmentInformation.hostname = nil
        enrollmentInformation.organizationGroup = nil
        self.sdkController.context.enrollmentInformation = enrollmentInformation
        self.populateEnvironmentInformation()
    }
}
