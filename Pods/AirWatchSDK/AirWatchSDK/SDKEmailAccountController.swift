//
//  SDKEmailAccountController.swift
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


protocol SDKEmailAccountControllerDataSource {
    var enrollmentInformation: EnrollmentInformation? { get set }

}


protocol SDKEmailAccountControllerDelegate: class {
    func attemptAutodiscovery(email: String?, completion: @escaping ((Bool)->Void))
    func manualSetupWithServerDetails()
    func saveEnrollmentUserEmailAddress(emailAddress: String?)
}

extension SDKEmailAccountControllerDelegate {
    
    func showAutoDiscoveryErrorMessage(message: String) {
        let _ = KeyWindowAlert(title: AWSDKLocalizedString("ErrorTitle"), message: message).show()
    }
}


protocol SDKEmailAccountController: EmailAccountViewControllerDelegate {
    var presenter: SDKQueuePresenter { get }
    var dataSource: SDKEmailAccountControllerDataSource? { get set }
    weak var delegate: SDKEmailAccountControllerDelegate? { get set }
}

extension SDKEmailAccountController {
    
    func showEmailAccountViewController() {
        if let _ = dataSource {
            presenter.displayEmailAccountScreen(delegate: self)
        }
    }
    
    func attemptAutodiscovery(email: String?, completionHandler completion: @escaping ((Bool)->Void)) {
        self.delegate?.attemptAutodiscovery(email: email){ (success) in
            if !success {
                ///Failure; Push to server details
                self.manualSetupWithServerDetails()
            }
            completion(success)
        }
    }
    
    func endUserLicenseAgreementRequested() -> String {
        return "" ///TODO::
    }
    
    func manualSetupWithServerDetails() {
        self.delegate?.manualSetupWithServerDetails()
    }
    
    func saveEmail(email: String){
        self.delegate?.saveEnrollmentUserEmailAddress(emailAddress: email)
    }
}











