//
//  ReviewEnrollmentInformationSetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2017 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWPresentation
import AWHelpers
import AWLocalization
import AWServices

internal protocol ReviewEnrollmentSetupHelper: class, ServerDetailsViewControllerDelegate {

    func canUseAsReviewEnvironment(hostname: String, group: String) -> Bool

    func setupReviewEnvironment()

    func verifyReviewEnvironmentAvailability(hostname: String, validator: EnvironmentValidator.Type, completionHandler: @escaping ((_ validated: Bool)->Void))

    func presentUserMessage(title: String, message: String)
}

internal protocol EnvironmentValidator {
    static func validateAuthenticationServicesAvailability(_ hostname: String, completion:@escaping (_ validatedHostname: String?, _ error: NSError?) -> Void)
}

extension AuthenticationServices: EnvironmentValidator {}

internal extension ReviewEnrollmentSetupHelper where Self: SDKSetupAsyncOperation {

    //Delegate method implementation when user enters server details and og and press next.
    internal func validateServerDetails(_ url: String?, organizationGroup: String?, completionHandler: @escaping ((Bool)->Void)) {

        guard let providedURL = url, let providedGroup = organizationGroup else {
            self.presentUserMessage(title: "Error".localized, message: "Please enter Server URL and Organization Group")
            completionHandler(false)
            return
        }

        if self.canUseAsReviewEnvironment(hostname: providedURL, group: providedGroup) {
            self.setupReviewEnvironment()
            completionHandler(true)
            return
        }

        self.verifyReviewEnvironmentAvailability(hostname: providedURL, validator: AuthenticationServices.self) {[weak self] (validated) in
            //This message need not be localized.
            let errorMessage = validated ? "This environment requires you to sign-in with either AirWatch Agent or Workspace One." : "Please enter a valid server URL and group ID to continue."
            self?.presentUserMessage(title: "Error".localized, message: errorMessage)
            completionHandler(false)
        }

    }

    internal func userDidDismissServerDetailsViewController() {
        self.presenter.pop()
        self.markOperationFailed()
    }

    internal func canUseAsReviewEnvironment(hostname: String, group: String) -> Bool {

        let userInput = hostname.hasPrefix("http") ? hostname : "https://\(hostname)"
        // Check if user have entered both Server URL and organization group
        guard
            let providedURLComonents = NSURLComponents(string: userInput),
            let providedHost = providedURLComonents.host?.lowercased()
            else {
            return false
        }

        // Compare provided URL with Plist Information.
        guard
            let testServerURL = SDKDefaultSettings.sharedSettings.testEnrollmentServerURL(),
            let testServerURLComponents = URLComponents(string: testServerURL),
            let testServerHost = testServerURLComponents.host?.lowercased(),
            testServerHost == providedHost,
            let testGroup = SDKDefaultSettings.sharedSettings.testEnrollmentOrganizationGroup()?.lowercased(),
            testGroup == group.lowercased()
        else {
            log(error: "Trying to use Enrollment Setup Operation without Default Server URL and Organization Group(T)")
            return false
        }

        return true
    }

    internal func verifyReviewEnvironmentAvailability(hostname: String,
                                             validator: EnvironmentValidator.Type,
                                             completionHandler: @escaping ((Bool)->Void)) {

        validator.validateAuthenticationServicesAvailability(hostname) { (validatedURL, error) in
            completionHandler(validatedURL != nil)
        }

    }

    internal func setupReviewEnvironment() {
        let generatedUDID = Data.randomData(count: 100).sha1?.hexadecimalString ?? SDKDefaultSettings.sharedSettings.mockedSimulatorUDID()
        log(debug: "Creating Test Enrollment Information. (T)")

        let enrollmentInfo = EnrollmentInformation()
        enrollmentInfo.deviceIdentifier = generatedUDID
        enrollmentInfo.hostname = SDKDefaultSettings.sharedSettings.testEnrollmentServerURL()
        enrollmentInfo.organizationGroup = SDKDefaultSettings.sharedSettings.testEnrollmentOrganizationGroup()

        log(debug: "Saving Created information. (T)")
        self.dataStore.enrollmentInformation = enrollmentInfo
        self.dataStore.consoleVersion = ConsoleVersion.minimumSupportedVersion  //Save as minimum supported version until we get latest information from server.
        self.markOperationComplete()
        log(info: "Enrollment information setup complete. (T)")

    }

    internal func presentUserMessage(title: String, message: String) {
        _ = KeyWindowAlert(title: title, message: message).show()
    }

}

internal class ReviewEnrollmentInformationSetupOperation: SDKSetupAsyncOperation, ReviewEnrollmentSetupHelper {

    //Default method to override and provide implementation for the operation.
    override func startOperation() {
        self.presenter.displayServerDetails(delegate: self, serverURL: nil, serverGroup: nil)
    }

}



















