//
//  SDKChangePasscodeViewController.swift
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

open class SDKChangePasscodeViewController: ChangePasscodeViewController {

    @IBOutlet weak var scrollView: UIScrollView?
    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    var nextButtonMovementHandler: NextButtonMovementController?
    
    fileprivate var oldPasscodeText: String? = ""
    
    // used for unit tests
    internal var alert: KeyWindowAlert? = nil
    override open func viewDidLoad() {
        log(verbose: "ViewDidLoad: SDKChangePasscodeViewController")
        super.viewDidLoad()
        
        switch changePasscodeProgressStage {
        case .validateOldPasscode:
             passcodeTextView?.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("CurrentPassword"), attributes:nil)
            break
        case .enterNewPasscode:
             passcodeTextView?.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("CreatePasscode"), attributes:nil)
            break
        case .confirmNewPasscode:
             passcodeTextView?.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("ConfirmPasscode"), attributes:nil)
            nextButton?.setTitle(AWSDKLocalization.getLocalizationString("Confirm"), for: UIControlState.normal)
             _ = passcodeTextView?.textField?.becomeFirstResponder()
            break
        }
        
         passcodeTextView?.textField?.addTarget(self, action: #selector(textDidChange),
                                           for: UIControlEvents.editingChanged)
        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error: "nextButtonVerticalConstraintFromBottom not set")
            return
        }
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log(verbose: "ViewWillAppear: SDKChangePasscodeViewController")
        ///This check is for the senario when we are currenting in confrim passcode and we
        ///come back to create view. The keyboard should be up already
        if  passcodeTextView?.textField?.text != "" {
             _ = passcodeTextView?.textField?.becomeFirstResponder()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
         passcodeTextView?.textField?.underlinedUnfocused() //add the underline
    }
    
    func oldPasscodeIsValid() -> Bool {
        guard let passcodeText =  passcodeTextView?.textField?.text else {
            log(error: "passcodeTextField contains no text")
            return false
        }
        guard let passcodeState: PasscodeValidationResult = delegatePasscodeValidator?.validatePasscode(passcodeText) else {
            log(error: "validation of old passcode returned nil")
            return false
        }
        
        switch passcodeState {
        case PasscodeValidationResult.ok:
            return true
        case PasscodeValidationResult.wrongPasscode:
            log(error: "Failed to enter the right passcode")
            return false
        case PasscodeValidationResult.maxFailedAttemptsMade:
            log(error: "Max failed attempts for passcode reached")
            changePasscodeDelegate?.changePasscodeViewControllerFinished(success: false, error: passcodeState.asNSError())
            return false
        }
    }
    
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        log(debug: "nextButtonTapped")
        
        guard let newChangePasscodeViewController = self.storyboard?.instantiateViewController(withIdentifier: "ChangePasscodeViewController") as? SDKChangePasscodeViewController else {
            log(error: "Failed to create new change passcode view controller.")
            return
        }
        self.disableUIElementsWhileProcessing()
        self.stopObservingApplicationLifecycleNotifications()
        
        //(1) which stage am i in?
        switch changePasscodeProgressStage {
        case .validateOldPasscode:
            if oldPasscodeIsValid() {
                ///push new view controller and enter "EnterNewPasscode" Stage
                guard let oldPasscodeText: String =  passcodeTextView?.textField?.text, oldPasscodeText != "" else{
                    log(debug: "old passcode incorrect" )
                    passcodeRestrictionLabel?.text = AWSDKLocalizedString("IncorrectPasscodeEntered")
                    passcodeRestrictionLabel?.isHidden = false
                    return
                }
                passcodeRestrictionLabel?.text = ""
                newChangePasscodeViewController.changePasscodeProgressStage = .enterNewPasscode
                newChangePasscodeViewController.changePasscodeDelegate = self //so that we can work back through the stack of changePasscodeVC's
                newChangePasscodeViewController.delegatePasscodeComplianceDetector = self.delegatePasscodeComplianceDetector
                newChangePasscodeViewController.oldPasscodeText = oldPasscodeText
                newChangePasscodeViewController.showSSOPasscodeFooterLabel = self.showSSOPasscodeFooterLabel
                self.navigationController?.pushViewController(newChangePasscodeViewController, animated: true)
            } else {
                passcodeTextView?.resetTextFieldToDefaultState() //clear and re-enable since passcode was incorrect
            }
            break
        case .enterNewPasscode:
            guard let potentialPasscode: String =  passcodeTextView?.textField?.text, potentialPasscode != "" else{
                log(error: "could not proceed because either passcode text view is nill or the length of the passcode does not have a length of greater than 0")
                return
            }
            newChangePasscodeViewController.changePasscodeProgressStage = .confirmNewPasscode
            newChangePasscodeViewController.potentialPasscode = potentialPasscode
            newChangePasscodeViewController.oldPasscodeText = oldPasscodeText
            newChangePasscodeViewController.changePasscodeDelegate = self //so that we can work back through the stack of changePasscodeVC's
            newChangePasscodeViewController.delegatePasscodeComplianceDetector = self.delegatePasscodeComplianceDetector
            newChangePasscodeViewController.showSSOPasscodeFooterLabel = self.showSSOPasscodeFooterLabel
            self.navigationController?.pushViewController(newChangePasscodeViewController, animated: true)
            break
        case .confirmNewPasscode:
            changePasscode()
            return
        }
        self.enableUIElementsForUserInput()
    }
    override func disableUIElementsWhileProcessing() {
        self.passcodeTextView?.textField?.isSecureTextEntry = true
        self.passcodeTextView?.textField?.disable()
        self.passcodeTextView?.showHideButton?.isEnabled = false
        self.passcodeTextView?.showHideButton?.alpha = AWColor.disabledAlphaValue
        self.cancelButton?.alpha = AWColor.disabledAlphaValue
        self.cancelButton?.isEnabled = false
        self.nextButton?.isEnabled = false
        self.activityIndicator?.startAnimating()
    }
    override func enableUIElementsForUserInput() {
        ///Re-enable everything incase user comes back to this screen
        self.passcodeTextView?.textField?.enable()
        self.passcodeTextView?.showHideButton?.isEnabled = true
        self.passcodeTextView?.showHideButton?.alpha = AWColor.enabledAlphaValue
        self.nextButton?.isEnabled = true
        self.cancelButton?.alpha = AWColor.enabledAlphaValue
        self.cancelButton?.isEnabled = true
        self.activityIndicator?.stopAnimating()
    }
    
    internal func textDidChange() -> Bool {
        guard let passcodeText =  passcodeTextView?.textField?.text else {
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
        switch changePasscodeProgressStage {
        case .validateOldPasscode:
            nextButton?.isEnabled = true
            nextButton?.isHidden = false
            return true
        case .enterNewPasscode:
            let passcodeCompliance: PasscodeComplianceResult = checkPasscodeIsValid()
            if passcodeCompliance.compliant {
                status = true
                passcodeRestrictionLabel?.text = AWSDKLocalizedString("ThatWorks")
            } else {
                passcodeRestrictionLabel?.text = passcodeCompliance.complianceMessage
            }
        case .confirmNewPasscode:
            if passcodeText == potentialPasscode {
                status = true
                passcodeRestrictionLabel?.text = AWSDKLocalizedString("ThatsAMatch")
            } else {
                passcodeRestrictionLabel?.text = AWSDKLocalizedString("PasscodesMustMatch")
            }
        }
        passcodeRestrictionLabel?.isHidden = false //show the restrictions message that is currently being violated
        
        nextButton?.isEnabled = status
        nextButton?.isHidden = !status
        return status
    }
    
    func checkPasscodeIsValid() -> PasscodeComplianceResult {
        let restrictor = delegatePasscodeComplianceDetector
        
        guard let passcodeText =  passcodeTextView?.textField?.text else {
            log(error: "passcodeTextField contains no text")
            return ComplianceResult(compliant: false, complianceMessage: "")
        }
        guard let complianceResult: PasscodeComplianceResult = restrictor?.passcodeCompliesWithRestrictions(passcodeText) else {
            log(error: "passcode compliance check return nil")
            return ComplianceResult(compliant: false, complianceMessage: "")
        }
        return complianceResult
    }


    // MARK: UITextFieldDelegate methods
    // When user taps `return` while focused on text field
    // Change to the next textfield or run
    // the private `changePasscode()` method (same method that gets called by button)
    // as needed
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let nextButton = nextButton else { return false }

        if nextButton.isHidden == false &&  nextButton.isEnabled == true {
            nextButtonTapped(nextButton)
            return true
        }
        return false
    }

    // MARK: UIButton Actions

    // Tells delegate that this view controller finished without successfully changing the passcode
    // allowing the delegate to do something (e.g. dismiss this view controller)
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        if changePasscodeProgressStage != .validateOldPasscode {
            _ = navigationController?.popViewController(animated: true)
        } else {
            changePasscodeDelegate?.changePasscodeViewControllerFinished(success: false, error: AWError.SDK.Presenter.userCanceled.error)
        }
    }

    // MARK: Private method
    // Used to actually change the passcode
    //
    // and then calls `changePasscode(:from:WithCompletionHandler:)` on `changePasscodeDelegate`,
    // where the completion handler contains code for this view contoller to react and call
    // `changePasscodeViewControllerFinished(success:error:)` on `changePasscodeDelegate` if successful
    internal func changePasscode() {
        guard let newPasscode =  passcodeTextView?.textField?.text, newPasscode == potentialPasscode, newPasscode != "" else {
            log(error: "new passcode doesnt match old passcode")
            ///it should never come here becuase user cannot click next button if newPasscode does not match oldPasscode
            return
        }
        self.cancelButton?.isEnabled = false
        changePasscodeDelegate?.changePasscode(new: newPasscode,
                                               old: oldPasscodeText,
                                               completionHandler: { (success, error) in
            if success {
                log(verbose: "Successfully changed passcode")
            } else {
                self.cancelButton?.isEnabled = true
                log(error: "Failed to change passcode")
            }
            self.changePasscodeDelegate?.changePasscodeViewControllerFinished(success: success, error: error)
        })
    }
    
    override func handleApplicationDidEnterBackground() {
        self.activityIndicator?.stopAnimating()
        self.passcodeTextView?.resetTextFieldToDefaultState()
        self.nextButton?.isHidden = true
        self.passcodeRestrictionLabel?.text = ""
    }
}

fileprivate struct ComplianceResult: PasscodeComplianceResult {
    public var complianceMessage: String
    public var compliant: Bool
    
    init(compliant: Bool, complianceMessage: String) {
        self.compliant = compliant
        self.complianceMessage = complianceMessage
    }
}
