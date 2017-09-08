//
//  EnrollmentPreparation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWError
import AWPresentation

import AWServices

protocol EnrollmentControllerDelegate: class {
    func enrollmentInformationDidSetup(_ enrollment: EnrollmentInformation)
    func enrollmentInformationSetupFailed(_ error: AWError.SDK.Enrollment.General)
    func enrollmentCheckCompleted(_ status: AWSDK.EnrollmentStatus)
    func enrollmentCheckFailed(_ error: Error?)
}

protocol EnrollmentController: class, SDKServerDetailsControllerDelegate, SDKEmailAccountControllerDelegate {
    var context: SDKContext { get set }
    var presenter: SDKQueuePresenter { get }
    var serverDetailsController: SDKServerDetailsController { get }
    var emailAccountController: SDKEmailAccountController { get }
    weak var delegate: EnrollmentControllerDelegate? { get }
    var isEnrollmentInformationAvaialble: Bool { get }
    func verifyCurrentEnrollment()
    func setupEnrollmentInformation()
}

extension EnrollmentController {
    // Derived / Computed Properties
    var isEnrollmentInformationAvaialble: Bool {
        if let enrollmentInfo = self.context.enrollmentInformation {
            return enrollmentInfo.isComplete
        }
        return false
    }

    func setupEnrollmentInformation() {
        self.serverDetailsController.showServerDetails()
    }

    //Public Methods
    func verifyCurrentEnrollment() {

        guard let enrollmentInformation = self.context.enrollmentInformation else {
            delegate?.enrollmentCheckFailed(AWError.SDK.Enrollment.General.incompleteEnrollmentInformationForVerfication.error)
            self.setupEnrollmentInformation()
            return
        }
        
        self.checkEnrollmentStatus(enrollmentInformation, controller: serverDetailsController)
    }

    func continueWithEnrollmentInformation(_ enrollment: EnrollmentInformation, status: AWSDK.EnrollmentStatus, controller: SDKServerDetailsController) {
        //Save updated enrollment information

        context.enrollmentInformation = enrollment

        //TODO: Currently process with enrolled. until cleared.
        self.delegate?.enrollmentCheckCompleted(status)
    }

    func enrollmentCheckFailed(_ error: Error?) {
        self.delegate?.enrollmentCheckFailed(error)
    }

    func updateEnrollmentInformation(_ enrollment: EnrollmentInformation, controller: SDKServerDetailsController) {
        //Should thus restart SDK?
        self.context.wipeApplicationData()
        self.context.enrollmentInformation = enrollment
        self.delegate?.enrollmentInformationDidSetup(enrollment)
    }

    func userDidDismissServerDetailsViewController() {
        if (self.context.enrollmentInformation != nil) {
            self.delegate?.enrollmentInformationSetupFailed(.userCancelledEnrollmentInformationSetup)
            return
        }
        // Do not do anything until server details were entered.
    }
}

class EnrollmentServerDetailsController: SDKServerDetailsController {
    var presenter: SDKQueuePresenter
    var dataSource: SDKServerDetailsControllerDatasource?
    weak var delegate: SDKServerDetailsControllerDelegate?
    init(presenter: SDKQueuePresenter) {
        self.presenter = presenter
    }
}

class EnrollmentEmailAccountController: SDKEmailAccountController {
    var presenter: SDKQueuePresenter
    var dataSource: SDKEmailAccountControllerDataSource?
    weak var delegate: SDKEmailAccountControllerDelegate?
    
    init(presenter: SDKQueuePresenter) {
        self.presenter = presenter
    }
}


class SDKEnrollmentController: EnrollmentController, SDKServerDetailsControllerDelegate, SDKEmailAccountControllerDelegate {

    var context: SDKContext
    var presenter: SDKQueuePresenter

    let serverDetailsController: SDKServerDetailsController
    let emailAccountController: SDKEmailAccountController
    weak var delegate: EnrollmentControllerDelegate?

    init(presenter: SDKQueuePresenter, context: SDKContext) {
        self.presenter = presenter
        self.context = context

        let serverDetailsController = EnrollmentServerDetailsController(presenter: presenter)
        serverDetailsController.dataSource = self.context
        self.serverDetailsController = serverDetailsController
        
        let emailAccountController = EnrollmentEmailAccountController(presenter: presenter)
        emailAccountController.dataSource = self.context
        self.emailAccountController = emailAccountController

        //Done initialization
        serverDetailsController.delegate = self
        emailAccountController.delegate = self
    }

    deinit {
        serverDetailsController.delegate = nil
        serverDetailsController.dataSource = nil

        emailAccountController.delegate = nil
        emailAccountController.dataSource = nil
    }

    func manualSetupWithServerDetails() {
        
        self.serverDetailsController.showServerDetails()
    }
    
    func attemptAutodiscovery(email: String?, completion: @escaping ((Bool)->Void)) {
        //TODO:: this method of differicitating between QA environments is deprecated
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
        autoDiscovery?.requestServerDetails(withDomain:emailDomain) {[weak self] (response, error) in
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
            self?.serverDetailsController.validateServerDetails(serverURL, organizationGroup: orgGroup, completionHandler: completion)
        }
    }
    
    internal func saveEnrollmentUserEmailAddress(emailAddress: String?) {
        guard let email: String = emailAddress else {
            log(error: "Attempt to save nil email address as enrollmentUserEmailAddress")
            return
        }
        log(debug: "Saving enrollmentUserEmailAddress")
        self.context.enrolledUserEmailAddress = email
    }
}
