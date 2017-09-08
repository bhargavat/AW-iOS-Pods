//
//  SDKPasscodeValidationViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import AWLocalization
import Foundation

open class SDKPasscodeValidationViewController: PasscodeValidationViewController {
    
    @IBOutlet weak var scrollView: UIScrollView?
    var nextButtonMovementHandler: NextButtonMovementController?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        log(verbose:"ViewDidLoad: AuthenticationViewController")
        
        self.passcodeTextView?.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("Passcode"),
                                                                      attributes:nil)
        self.forgotPasscodeButton?.setTitle(AWSDKLocalization.getLocalizationString("ForgotPasscode"), for: .normal)
        
        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error:"nextButtonVerticalConstraintFromBottom not set")
            return
        }
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log(verbose:"ViewWillAppear: SDKPasscodeValidationViewController")
        
        ScrollViewHandler.sharedInstance.scrollView = scrollView
        ScrollViewHandler.sharedInstance.viewToScrollTo = nextButton
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.promptTouchID {
            log(verbose: "SDKPasscodeValidationViewController: prompting for TouchID")
            self.touchIDButtonPressed()
        } else { // if we're are going to display the touchID prompted then no textFeild should become the first responder
            _ = self.passcodeTextView?.textField?.becomeFirstResponder()
        }
        self.passcodeTextView?.textField?.underlinedUnfocused() //add the underline
    }
    
    @IBAction open func nextButtonPressed() {
        guard let passcodeTextField = passcodeTextView?.textField, let passcodeText = passcodeTextField.text else {
            log(error:"Storyboard was not connected with passcode text field")
            return
        }
        //disable and grey out the other buttons
        self.disableUIElementsWhileProcessing()
        
        // At the moment passcodeValidationDelegate?.passcodeValidator is not async and thus as a preventative maintanence we remove lifecycle events
        self.stopObservingApplicationLifecycleNotifications()
        
        if showTouchIDButton {
            self.touchIDButton?.isEnabled = false
            self.touchIDButton?.alpha = AWColor.disabledAlphaValue
        }
        
        if passcodeValidationDelegate?.passcodeValidator(passcodeText) == PasscodeValidationResult.wrongPasscode {
            self.resetValuesToStartStateOfController()
            self.displayButtonsCorrectlyAndSetFirstResponder()
            self.startObservingApplicationLifecycleNotifications()
        }
        
    }
    
    override func handleApplicationDidEnterBackground() {
        self.resetValuesToStartStateOfController()
    }
    override func handleApplicationWillEnterForeground() {
        self.displayButtonsCorrectlyAndSetFirstResponder()
    }

    func resetValuesToStartStateOfController() {
        self.nextButton?.isHidden = true
        self.activityIndicator?.stopAnimating()
        self.passcodeTextView?.resetTextFieldToDefaultState()
    }
    func displayButtonsCorrectlyAndSetFirstResponder() {
        _ = self.passcodeTextView?.textField?.becomeFirstResponder()
        _ = self.textDidChange()

        self.forgotPasscodeButton?.isEnabled = true
        self.forgotPasscodeButton?.alpha = AWColor.enabledAlphaValue

        if self.showTouchIDButton {
            self.touchIDButton?.isEnabled = true
            self.touchIDButton?.alpha = AWColor.enabledAlphaValue
        }
    }

    // MARK: UITextFieldDelegate methods
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = passcodeTextView?.textField?.text, text != "" {
            nextButtonPressed()
        }
        return false
    }
}
