//
//  SDKCreatePasscodeViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWLocalization
import AWError

open class SDKCreatePasscodeViewController: CreatePasscodeViewController {

    @IBOutlet weak var scrollView: UIScrollView?

    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    var nextButtonMovementHandler: NextButtonMovementController?

    // used for unit tests
    internal var alert: KeyWindowAlert? = nil
    
    private var newPasscodeEntered: Bool = false    //true only after the user has entered the new passcode once
    private var newPasscodeConfirmed: Bool = false  //true only after the user has entered the new passcode a second time
    private var potentialPasscode: String = ""
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        log(verbose: "ViewDidLoad: SDKCreatePasscodeViewController")

        if !newPasscodeEntered {
            createPasscodeTextView?.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("CreatePasscode"), attributes:nil)
        } else { // we are now on the confirm passcode screen
            createPasscodeTextView?.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("ConfirmPasscode"), attributes:nil)
            nextButton?.setTitle(AWSDKLocalization.getLocalizationString("Confirm"), for: UIControlState.normal)
            cancelButton?.isHidden = false
            self.cancelButton?.isEnabled = true
            _ = createPasscodeTextView?.textField?.becomeFirstResponder()
        }
        
        createPasscodeTextView?.textField?.addTarget(self,
                                     action: #selector(textDidChange),
                                     for: UIControlEvents.editingChanged)

        nextButton?.isEnabled = false
        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error: "nextButtonVerticalConstraintFromBottom not set")
            return
        }
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log(verbose: "ViewWillAppear: SDKCreatePasscodeViewController")
        ScrollViewHandler.sharedInstance.scrollView = scrollView
        ScrollViewHandler.sharedInstance.viewToScrollTo = nextButton
        
        ///This check is for the senario when we are currenting in confrim passcode and we
        ///come back to create view. The keyboard should be up already
        if createPasscodeTextView?.textField?.text != "" {
            _ = createPasscodeTextView?.textField?.becomeFirstResponder()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        createPasscodeTextView?.textField?.underlinedUnfocused() //add the underline
        createPasscodeTextView?.textField?.delegate = self
    }

    // MARK: UITextField actions
    // When the user types in their new passcode, checks if it follows restrictions,
    // and displays/hides the checkmark as needed
    // When the user types in the confirm passcode textfield, checks if it equals the new passcode
    // and displays/hides the checkmark as needed
    internal func textDidChange() -> Bool {
        guard let passcodeText = createPasscodeTextView?.textField?.text else {
            log(error: "Storyboard's passcode and text field is not set.")
            nextButton?.isEnabled = false
            return false
        }
        
        guard passcodeText != "" else {
            passcodeRestrictionLabel?.isHidden = true
            nextButton?.isEnabled = false
            nextButton?.isHidden = true
            return false
        }
        
        var status = false
        if !newPasscodeEntered { ///creating passcode
            
            let passcodeCompliance: PasscodeComplianceResult = checkPasscodeIsValid()
            if passcodeCompliance.compliant {
                status = true
                passcodeRestrictionLabel?.text = AWSDKLocalizedString("ThatWorks")
            } else {
                passcodeRestrictionLabel?.text = passcodeCompliance.complianceMessage
            }
            
        } else { ///confirming passcode
            if passcodeText == potentialPasscode {
                status = true
                passcodeRestrictionLabel?.text = AWSDKLocalizedString("ThatsAMatch")

            } else {
                passcodeRestrictionLabel?.text = AWSDKLocalizedString("PasscodesMustMatch")
            }
        }
        passcodeRestrictionLabel?.isHidden = false //show the restrictions message that is currently being violated
        
        
        if status {
            nextButton?.isEnabled = true
            nextButton?.isHidden = false
        } else {
            nextButton?.isEnabled = false
            nextButton?.isHidden = true
        }
        
        return status
    }
    
    internal func doesNewPasscodeConfirmToRestrictions() -> Bool {
        let checkPasscode = checkPasscodeIsValid()
        if checkPasscode.compliant == false {
            let passcodeRestrictionTitle = AWSDKLocalization.getLocalizationString("Notice")
            let passcodeRestrictions = AWSDKLocalization.getLocalizationString("Passworddonotcomplyrestriction")

            alert = KeyWindowAlert.init(title: passcodeRestrictionTitle, message: passcodeRestrictions)
            _ = alert?.show()
            _ = createPasscodeTextView?.textField?.becomeFirstResponder()
            return false
        }
        return true
    }
    
    
    func checkPasscodeIsValid() -> PasscodeComplianceResult {
        let restrictor = delegatePasscodeComplianceDetector
        let complianceResult: PasscodeComplianceResult = (restrictor?.passcodeCompliesWithRestrictions(createPasscodeTextView?.textField?.text))!
        return complianceResult
    }

    // MARK: UIButton Actions
    // Presents the passcode restrictions, as provided by the app-level
    @IBAction func infoButtonTapped(_ sender: UIButton) {
        let passcodeRestrictionTitle = AWSDKLocalization.getLocalizationString("PasscodeRestriction")
        let passcodeRestrictions = delegatePasscodeComplianceDetector?.getPasscodeRestrictions()
        alert = KeyWindowAlert.init(title: passcodeRestrictionTitle, message: passcodeRestrictions)
        _ = alert?.show()
    }

    // Calls private createPasscode() method which implements checks
    // & calls to app level for creating the passcode
    @IBAction func createButtonTapped(_ sender: UIButton) {
        createPasscode()
    }

    // Tells delegate that this view controller finished without successfully creating the passcode
    // allowing the delegate to do something (e.g. dismiss this view controller)
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        if newPasscodeEntered == true { /// if we are on the confirm passcode screen
            _ = navigationController?.popViewController(animated: true)
        } else {
        createPasscodeDelegate?.createPasscodeViewControllerFinished(success: false,
                                                                     error: AWError.SDK.Presenter.userCanceled.error)
        }
    }

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        /// (1) figure out if this is create passcode, or confirm passcode actions
        self.createPasscodeTextView?.textField?.disable()
        self.createPasscodeTextView?.showHideButton?.isEnabled = false
        self.createPasscodeTextView?.showHideButton?.alpha = AWColor.disabledAlphaValue
        self.nextButton?.isEnabled = false
        self.createPasscodeTextView?.textField?.isSecureTextEntry = true
        self.activityIndicator?.startAnimating()
        
        // Good practice to disable life cycle notification to be similar to other view controllers
        self.stopObservingApplicationLifecycleNotifications()
        
        if self.newPasscodeEntered == false {
            /// (2.a) if create: reload for confirm
            guard let newCreatePasscodeViewController = self.storyboard?.instantiateViewController(withIdentifier: "CreatePasscodeViewController") as? SDKCreatePasscodeViewController else {
                log(error: "Next button tapped, but new passcode text view is nil or potential passcode is length 0.")
                return
            }
            newCreatePasscodeViewController.newPasscodeEntered = true // so that the next view controller knows that it is in the confirm passcode stage
            guard let potentialPasscode: String = createPasscodeTextView?.textField?.text, potentialPasscode != "" else{
                log(error: "Next button tapped, but create passcode text view is nil or potential passcode is length 0.")
                return
            }
            newCreatePasscodeViewController.potentialPasscode = potentialPasscode
            newCreatePasscodeViewController.createPasscodeDelegate = self.createPasscodeDelegate
            newCreatePasscodeViewController.delegatePasscodeComplianceDetector = self.delegatePasscodeComplianceDetector
            newCreatePasscodeViewController.showSSOPasscodeFooterLabel = self.showSSOPasscodeFooterLabel
            self.navigationController?.pushViewController(newCreatePasscodeViewController, animated: true)
            
            ///Re-enable everything incase they come back
            self.createPasscodeTextView?.textField?.enable()
            self.nextButton?.isEnabled = true
            self.activityIndicator?.stopAnimating()
            self.createPasscodeTextView?.showHideButton?.isEnabled = true
            self.createPasscodeTextView?.showHideButton?.alpha = AWColor.enabledAlphaValue
        } else { ///(2.b )we have confirmed the passcode, now create it
            self.createPasscode()
        }
        
        self.startObservingApplicationLifecycleNotifications()
    }

    
    fileprivate func createPasscode() {
        let localizedString_Notice = AWSDKLocalization.getLocalizationString("Notice")
        let localizedString_Error = AWSDKLocalization.getLocalizationString("ErrorTitle")
        guard let passcode = createPasscodeTextView?.textField?.text
            else {
                // Alert that the passcodeTextFields are not accessible
                let message = AWSDKLocalization.getLocalizationString("PleaseContactYourAdminstrator")
                    + " Passcode text fields not accessible by the SDK"
                alert = KeyWindowAlert.init(title: localizedString_Error, message: message)
                _ = alert?.show()
                return
        }

        guard !passcode.isEmpty
            else {
                // Alert that the passcode is empty
                let message = AWSDKLocalization.getLocalizationString("EnterPasscodeError")
                alert = KeyWindowAlert.init(title: localizedString_Notice, message: message)
                _ = alert?.show()
                _ = createPasscodeTextView?.textField?.becomeFirstResponder()
                return
        }
        guard passcode == potentialPasscode
            else {
                // Alert that the passcodes are not equal
                //"PasscodeDidntMatch"
                let message = AWSDKLocalization.getLocalizationString("PasscodeDidntMatch")
                alert = KeyWindowAlert.init(title: localizedString_Notice, message: message)
                _ = alert?.show()
                return
        }
        
        guard let restrictor = delegatePasscodeComplianceDetector
            else {
                // Alert or log that restrictor is not implemented
                let message = AWSDKLocalization.getLocalizationString("PleaseContactYourAdminstrator")
                    + "   not set"
                alert = KeyWindowAlert.init(title: localizedString_Error, message: message)
                _ = alert?.show()
                return
        }

        let passcodeCompliance: PasscodeComplianceResult = restrictor.passcodeCompliesWithRestrictions(passcode)
        self.cancelButton?.isEnabled = false
        self.activityIndicator?.startAnimating()
        if passcodeCompliance.compliant {
            log(debug: "New passcode option complies with all passcode restrictions")
        } else {
            log(debug: "New passcode option fails to comply with all passcode restrictions")
            log(debug: passcodeCompliance.complianceMessage)
            let message = AWSDKLocalization.getLocalizationString("Passworddonotcomplyrestriction")
                + " " + AWSDKLocalization.getLocalizationString("PasscodePolicyViolation")
            alert = KeyWindowAlert.init(title: localizedString_Notice, message: message)
            _ = alert?.show()
            self.cancelButton?.isEnabled = true
            return
        }
        
        createPasscodeDelegate?.createPasscode(new: passcode, confirm: potentialPasscode) { (success, errorOpt) in
            if success == false {
                self.cancelButton?.isEnabled = true
            }
            self.createPasscodeDelegate?.createPasscodeViewControllerFinished(success:success, error: errorOpt)
        }
    }
    
    //MARK: UITextFieldDelegate Methods
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let nextButtonEnabled = nextButton?.isEnabled ?? false
        let nextButtonHidden = nextButton?.isHidden ?? false
        if textField == createPasscodeTextView?.textField && nextButtonEnabled && !nextButtonHidden {
            nextButtonTapped(UIButton.init())
        }
        return false
    }
    
    override func handleApplicationDidEnterBackground() {
        self.activityIndicator?.stopAnimating()
        self.nextButton?.isHidden = true
        self.createPasscodeTextView?.resetTextFieldToDefaultState()
        self.passcodeRestrictionLabel?.text = ""
    }
}
