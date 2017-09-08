//
//  SDKServerDetailsController.swift
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
import AWError
import AWLocalization
import AWPresentation


protocol SDKServerDetailsControllerDatasource {
    var enrollmentInformation: EnrollmentInformation? { get set }
    /** 
     The default implementation will return a modified EnrollmentInformation object which was set if one existed. If the enrollmentInformation is never set then a new one will be returned.
     */
    mutating func createEnrollmentInformation(_ url: String, orgGroup: String) -> EnrollmentInformation?
}

protocol SDKServerDetailsControllerDelegate: class {
    func canUserDismissServerDetails(_ enrollment: EnrollmentInformation?) -> Bool
    func didDismissServerDetailsViewController(_ controller: SDKServerDetailsController)
    func validateUserInput(_ url: String?, organizationGroup: String?) -> Bool

    func updateEnrollmentInformation(_ enrollment: EnrollmentInformation, controller: SDKServerDetailsController)
    func validateServiceAvailability(_ enrollment: EnrollmentInformation,
                                     controller: SDKServerDetailsController,
                                     completionHandler: ((Bool)->Void)?)

    func checkEnrollmentStatus(_ enrollment: EnrollmentInformation, controller: SDKServerDetailsController)
    func continueWithEnrollmentInformation(_ enrollment: EnrollmentInformation, status: AWSDK.EnrollmentStatus, controller: SDKServerDetailsController)
    func enrollmentCheckFailed(_ error: Error?)
}

extension SDKServerDetailsControllerDelegate {

    func showEnrollmentErrorMessage(_ message: String) {
        let _ = KeyWindowAlert(title: AWSDKLocalizedString("ErrorTitle"), message: message).show()
    }

    func canUserDismissServerDetails(_ enrollment: EnrollmentInformation?) -> Bool {
        guard let enrollment = enrollment else { return false}
        return enrollment.isComplete
    }
    func didDismissServerDetailsViewController(_ controller: SDKServerDetailsController) {
        //default implementation does not do anything
    }

    func validateUserInput(_ url: String?, organizationGroup: String?) -> Bool {

        if let inputUrl = url, let inputOrgGroup = organizationGroup {
                let properURL = (inputUrl.lengthOfBytes(using: String.Encoding.utf8) > 0)
                let properOrgGroup = (inputOrgGroup.lengthOfBytes(using: String.Encoding.utf8) > 0)
            if properURL && properOrgGroup {
                return true
            }
        }
        showEnrollmentErrorMessage("Invalid Server URL")
        return false
    }

    func validateServiceAvailability(_ enrollment: EnrollmentInformation,
                                     controller: SDKServerDetailsController,
                                     completionHandler: ((Bool)->Void)?) {
        let delegte: SDKServerDetailsControllerDelegate = self
        
        guard let hostname = enrollment.hostname else {
            delegte.showEnrollmentErrorMessage(AWSDKLocalizedString("InvalidServerURLErrorMessage"))
            completionHandler?(false)
            return
        }
        
        AuthenticationServices.validateAuthenticationServicesAvailability(hostname) { [weak delegte] (validatedHostname, error) in

            guard error == nil else {
                delegte?.showEnrollmentErrorMessage(AWSDKLocalizedString("ServerURLConnectionError"))
                completionHandler?(false)
                return
            }

            guard validatedHostname?.lengthOfBytes(using: String.Encoding.utf8) != 0 else {
                delegte?.showEnrollmentErrorMessage(AWSDKLocalizedString("ServerURLConnectionError"))
                completionHandler?(false)
                return
            }
            
            enrollment.hostname = validatedHostname
            enrollment.lastVerifiedDate = nil
            self.updateEnrollmentInformation(enrollment, controller: controller)
            completionHandler?(true)
        }
    }

    func updateEnrollmentInformation(_ enrollment: EnrollmentInformation, controller: SDKServerDetailsController) {
        self.checkEnrollmentStatus(enrollment, controller: controller)
    }

    func checkEnrollmentStatus(_ enrollment: EnrollmentInformation, controller: SDKServerDetailsController) {
        
        if enrollment.organizationGroup == nil {
            //need to set a OG for cases from 5.9.x SDK where we do not have a OG stored, we set it back after we hit the status endpoint below
            enrollment.organizationGroup = "vmware-airwatch-dummyOrganizationGroup"
        }
        
        guard let enrollmentConfig = ConsoleServicesConfig(enrollmentInfo: enrollment) else {
            showEnrollmentErrorMessage("Missing Required Information")
            return
        }

        let delegate = self
        var shouldReportEnrollmentCheckFailure = true
        EnrollmentServices(config: enrollmentConfig).fetchEnrollmentStatus {[weak delegate] (enrollmentInfo, error) in
            guard shouldReportEnrollmentCheckFailure else {
                //Need not report the duplicate enrollmentcheck.
                return
            }
            shouldReportEnrollmentCheckFailure = false

            guard error == nil, let enrollmentInfo = enrollmentInfo else {
                delegate?.enrollmentCheckFailed(error)
                return
            }

            enrollment.lastVerifiedDate = Date()
            
            let enrollmentStatus = AWSDK.EnrollmentStatus(rawValue: enrollmentInfo.enrollmentStatus.rawValue) ?? .unknown
            enrollment.lastKnownEnrollmentStatus = enrollmentStatus
            enrollment.organizationGroup = enrollmentInfo.deviceGroupID
            
            AWController.sharedInstance.context.consoleVersion = ConsoleVersion(value:  enrollmentInfo.consoleVersion)
            
            delegate?.continueWithEnrollmentInformation(enrollment, status: enrollmentStatus, controller: controller)
        }

        NetworkConnectivityStatusManager.canConnectTo(host: enrollmentConfig.airWatchServerURL) { [weak delegate] (canConnect, connectionError) in

            //Need not report the duplicate enrollmentcheck.
            guard shouldReportEnrollmentCheckFailure else { return }

            guard canConnect else {
                log(info: "could not connect to host: \(String(describing: connectionError?.localizedDescription))")
                shouldReportEnrollmentCheckFailure = false
                delegate?.enrollmentCheckFailed(connectionError)
                return
            }
        }
    }

    func enrollmentCheckFailed(_ error: Error?) {
        self.showEnrollmentErrorMessage("Can not Validate Enrollment Status")
    }

    func continueWithEnrollmentInformation(_ enrollment: EnrollmentInformation, status: AWSDK.EnrollmentStatus, controller: SDKServerDetailsController) {
        if status == AWSDK.EnrollmentStatus.enrolled {
            controller.dismissServerDetailsViewConroller()
        } else {
            showEnrollmentErrorMessage("Device is not enrolled: \(status)")
        }
    }
}

protocol SDKServerDetailsController: ViewControllerDisplaySettingsDelegate, ServerDetailsViewControllerDelegate {
    var presenter: SDKQueuePresenter { get }
    var dataSource: SDKServerDetailsControllerDatasource? { get set}
    weak var delegate: SDKServerDetailsControllerDelegate? { get set}
    func dismissServerDetailsViewConroller()
}

extension SDKServerDetailsController {

    func showServerDetails() {
        if let dataSource = dataSource {
            let enrollmentInformation = dataSource.enrollmentInformation
            presenter.displayServerDetails(delegate: self, serverURL: enrollmentInformation?.hostname, serverGroup: enrollmentInformation?.organizationGroup)
        }
    }

    /// checking if url and organizationGroup are nils is actually done inside the function validateUserInput(::), 
    /// But we are adding the check here as well to remove the force unwrapping anyway
    func validateServerDetails(_ url: String?, organizationGroup: String?, completionHandler: @escaping ((Bool)->Void)) {
        if let delegate = delegate, var dataSource = dataSource {
            guard delegate.validateUserInput(url, organizationGroup: organizationGroup),
                let url = url, let orgGroup = organizationGroup else {
                    completionHandler(false)
                    return
            }
            
            if let enrollment = dataSource.createEnrollmentInformation(url, orgGroup: orgGroup) {
                delegate.validateServiceAvailability(enrollment, controller: self, completionHandler: {(success: Bool) in
                    completionHandler(success)
                })
            } else {
                //Display missing information error. can not validate server details error
                completionHandler(false)
            }
        }
    }

    func userDidDismissServerDetailsViewController() {
        dismissServerDetailsViewConroller()
    }

    func dismissServerDetailsViewConroller() {
        if let delegate = delegate {
            presenter.pop()
            delegate.didDismissServerDetailsViewController(self)
        }
    }
}
