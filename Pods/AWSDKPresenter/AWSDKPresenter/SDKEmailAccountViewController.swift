//
//  SDKEmailAccountViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLocalization

open class SDKEmailAccountViewController: EmailAccountViewConroller {
    
    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    var nextButtonMovementHandler: NextButtonMovementController?

    override open func viewDidLoad() {
        super.viewDidLoad()
        emailAddressTextField?.addTarget(self, action: #selector(textDidChange), for: UIControlEvents.editingChanged)
        termsAndConditionsButton?.setTitle(AWSDKLocalization.getLocalizationString("TermsAndConditions"), for: UIControlState.normal)

        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error: "nextButtonVerticalConstraintFromBottom not set")
            return
        }
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        emailAddressTextField?.underlinedUnfocused() //add the underline
    }

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        guard let delegate = emailAccountDelegate else{
            log(error: "Error: emailAccountDelegate not set")
            return
        }
        guard let email = emailAddressTextField?.text else {
            log(error: "Error: email textField is empty")
            return
        }
        emailAddressTextField?.isEnabled = false
        emailAddressTextField?.alpha = AWColor.disabledAlphaValue
        nextButton?.isEnabled = false

        manualSetupButton?.alpha = AWColor.disabledAlphaValue
        manualSetupButton?.isEnabled = false

        activityIndicator?.startAnimating()
        if let emailText: String = emailAddressTextField?.text {
            emailAccountDelegate?.saveEmail(email: emailText)
        }
        delegate.attemptAutodiscovery(email: email){ (success) in
            if success {
                log(debug: "Successfully used auto discovery")
            } else {
                log(debug: "Autodiscovery set up has failed")
            }
            DispatchQueue.main.async {
                self.updateViewsOnAutoDiscovertResponse()
            }
        }
    }
    
    func updateViewsOnAutoDiscovertResponse() {
        self.nextButton?.isEnabled = true
        self.activityIndicator?.stopAnimating()
        self.emailAddressTextField?.isEnabled = true
        self.emailAddressTextField?.alpha = AWColor.enabledAlphaValue
        manualSetupButton?.alpha = AWColor.enabledAlphaValue
        manualSetupButton?.isEnabled = true

    }
    
    @IBAction func termsAndConditionsTapped(_ sender: UIButton) {
        guard let delegate = emailAccountDelegate else{
            log(error:"Error: emailAccountDelegate not set")
            return
        }
        _ = delegate.endUserLicenseAgreementRequested()
        //TODO:: display the EULA
    }
    
    func isValidEmailAddress(emailText: String) -> Bool {
        let emailRegExValue = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        
        let emailTestPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegExValue)
        return emailTestPredicate.evaluate(with: emailText)
    }
    
    
    //MARK: UITextFieldDelegate Methods
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let nextButtonEnabled = nextButton?.isEnabled ?? false
        let nextButtonHidden = nextButton?.isHidden ?? false
        if textField == emailAddressTextField && nextButtonEnabled && !nextButtonHidden {
            nextButtonTapped(UIButton.init())
        }
        return false
    }
    
    func textDidChange() {
        var makeNextButtonActive = false
        guard let nextButton = nextButton else {
            return
        }
        guard let emailAddressText: String = emailAddressTextField?.text, emailAddressText != "" else {
            return
        }
        makeNextButtonActive = isValidEmailAddress(emailText: emailAddressText)
        nextButton.isEnabled = makeNextButtonActive
        nextButton.isHidden = !(makeNextButtonActive)
        if showTermsAndCondistionsButton {
            termsAndConditionsButton?.isEnabled = !(nextButton.isEnabled)
            termsAndConditionsButton?.isHidden = !(nextButton.isHidden)
        }
        manualSetupButton?.isHidden = nextButton.isHidden
        manualSetupButton?.isEnabled = nextButton.isEnabled
    }
}
