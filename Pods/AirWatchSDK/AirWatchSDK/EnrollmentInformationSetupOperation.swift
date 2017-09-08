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
import AWHelpers
import AWPresentation

class EnrollmentInformationSetupOperation: SDKSetupAsyncOperation, SDKServerDetailsControllerDatasource, SDKServerDetailsControllerDelegate, SDKEmailAccountControllerDataSource, SDKEmailAccountControllerDelegate {
    
    let serverDetailsController: EnrollmentServerDetailsController
    let emailAccountController: EnrollmentEmailAccountController

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        self.serverDetailsController = EnrollmentServerDetailsController(presenter: presenter)
        self.emailAccountController = EnrollmentEmailAccountController(presenter: presenter)
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        self.serverDetailsController.dataSource = self
        self.serverDetailsController.delegate = self
        self.emailAccountController.dataSource = self
        self.emailAccountController.delegate = self
    }

    override func startOperation() {
        log(debug: "Starting process to setup Enrollment Information")
        self.emailAccountController.showEmailAccountViewController()
    }
    
    // Autodiscover has failed and user clicked manual setup
    func manualSetupWithServerDetails() {
        self.serverDetailsController.showServerDetails()
    }
    
    func createEnrollmentInformation(_ url: String, orgGroup: String) -> EnrollmentInformation? {

        let enrollment = EnrollmentInformation()
        enrollment.hostname = url
        enrollment.organizationGroup = orgGroup
        if enrollment.deviceIdentifier == nil {
            guard let generatedUDID = UUID().uuidString.data(using: .utf8)?.sha1 else {
                return nil
            }
            enrollment.deviceIdentifier = generatedUDID.hexadecimalString
        }

        return enrollment
    }

    func updateEnrollmentInformation(_ enrollment: EnrollmentInformation, controller: SDKServerDetailsController) {
        self.dataStore.enrollmentInformation = enrollment
        self.dataStore.onboardedUser = self.dataStore.enrolledUser /// update onboardedUser now that we have server details
        self.markOperationComplete()
    }
    
    func updateEnrollmentInformation(_ enrollment: EnrollmentInformation, controller: SDKEmailAccountController) {
        self.dataStore.enrollmentInformation = enrollment
        self.markOperationComplete()
    }
    // We override this function so that when ServerDetails is displayed with wait waitUntilFinished is false, we handle when the user presses cancel the operation is marked as fail. 
    // This operation should be created with waitUntilFinished is false when blocker or authentication is pushed
    func userDidDismissServerDetailsViewController() {
        if self.canUserDismissServerDetails(self.dataStore.enrollmentInformation) {
            self.serverDetailsController.dismissServerDetailsViewConroller()
            self.markOperationFailed()
        }
    }

    func attemptAutodiscovery(email: String?, completion: @escaping ((Bool)->Void)) {
        //TODO:: this method of differenciating  between QA environments is deprecated
        //TODO:: consult with william about how the new way will work
        var autoDiscovery = AutoDiscoveryService(AutoDiscoveryHost: "discovery.awmdm.com")
        if SDKDefaultSettings.sharedSettings.isQAEnvironment() {
            autoDiscovery = AutoDiscoveryService(AutoDiscoveryHost: "qa17.airwatchqa.com")
        }
        
        guard let emailDomain: String = email?.components(separatedBy: "@").last else {
            log(error: "ERROR: failed to collect domain from email address for autodiscovery")
            completion(false)
            return
        }

        saveEnrollmentUserEmailAddress(emailAddress: email)
        autoDiscovery?.requestServerDetails(withDomain:emailDomain) { (response, error) in
            guard error == nil else {
                log(error: "ERROR: Autodiscovery failed: \(String(describing: error))")
                completion(false)
                return
            }
            guard let response = response else {
                log(error: "ERROR: Autodiscovery failed: response was nil")
                completion(false)
                return
            }
            let orgGroup: String = response.enrollmentOrgGroup
            let urlString: String = response.enrollmentUrl
            let serverURL: String = NSURL(string: urlString)?.host ?? urlString
            
            log(debug: "AutoDiscovery Successfully received url and organizationGroup!")
            log(debug: "AutoDiscovery url: \(serverURL)")
            log(debug: "AutoDiscovery OrgGroup: \(orgGroup)")
            self.serverDetailsController.validateServerDetails(serverURL,
                                                               organizationGroup: orgGroup,
                                                               completionHandler: completion)
        }
    }
    
    internal func saveEnrollmentUserEmailAddress(emailAddress: String?) {
        guard let email: String = emailAddress else {
            log(error: "Attempt to save nil email address as enrollmentUserEmailAddress")
            return
        }
        log(debug: "Saving enrollmentUserEmailAddress")
        self.dataStore.enrolledUserEmailAddress = email
    }

    var enrollmentInformation: EnrollmentInformation? {
        get {
            return self.dataStore.enrollmentInformation
        }
        set {
            self.dataStore.enrollmentInformation = newValue
        }
    }
}
