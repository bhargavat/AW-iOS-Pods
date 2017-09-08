//
//  EmailAddressViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit
import AWLocalization

open class EmailAccountViewConroller : BaseViewController {
    
    open weak var emailAccountDelegate: EmailAccountViewControllerDelegate?
    open var showTermsAndCondistionsButton: Bool = false
    
    @IBOutlet open weak var emailAddressTextField: SDKUITextField?
    @IBOutlet open weak var nextButton: UIButton?
    @IBOutlet open weak var termsAndConditionsButton: UIButton?
    @IBOutlet weak var manualSetupButton: UIButton?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        //keyboard should be down if terms and conditions are supposed to be shown; otherwise the email text field should already be the first responder
        if !showTermsAndCondistionsButton {
            _ = emailAddressTextField?.becomeFirstResponder()
        }
        
        termsAndConditionsButton?.isEnabled = showTermsAndCondistionsButton
        termsAndConditionsButton?.isHidden = !showTermsAndCondistionsButton
        
        emailAddressTextField?.delegate = self
        emailAddressTextField?.autocorrectionType = UITextAutocorrectionType.no
        emailAddressTextField?.keyboardType = UIKeyboardType.emailAddress
        manualSetupButton?.isHidden = true
        manualSetupButton?.isEnabled = false
        nextButton?.isEnabled = false
        nextButton?.isHidden = true
        
        manualSetupButton?.setTitle(AWSDKLocalizedString("ManualSetup"), for: UIControlState.normal)
        termsAndConditionsButton?.setTitle(AWSDKLocalization.getLocalizationString(""), for: UIControlState.disabled)
    }
    
    @IBAction func manualSetupButtonPressed(_ sender: UIButton) {
        guard let email = emailAddressTextField?.text else {
            log(error: "Error: email textField is empty")
            return
        }
        emailAccountDelegate?.saveEmail(email: email)
        emailAccountDelegate?.manualSetupWithServerDetails()
    }
}
