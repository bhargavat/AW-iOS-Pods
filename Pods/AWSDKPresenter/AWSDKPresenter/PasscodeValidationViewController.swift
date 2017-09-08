//
//  PasscodeValidationViewController.swift
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

open class PasscodeValidationViewController: BaseViewController {

    open weak var passcodeValidationDelegate: PasscodeValidationViewControllerDelegate?

    @IBOutlet open weak var touchIDButton: UIButton?
    @IBOutlet open weak var forgotPasscodeButton: UIButton?
    @IBOutlet open weak var nextButton: UIButton?
    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    @IBOutlet weak var passcodeTextView: SDKUIPasswordTextView?
    open var showTouchIDButton: Bool = false
    open var promptTouchID: Bool = false
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.nextButton?.isEnabled = false
        self.nextButton?.isHidden = true
        self.touchIDButton?.isHidden = !showTouchIDButton
        self.touchIDButton?.isEnabled = showTouchIDButton
    
        self.passcodeTextView?.textField?.addTarget(self, action: #selector(textDidChange), for: UIControlEvents.editingChanged)
        self.passcodeTextView?.textField?.delegate = self
    }
    
    required public init?(coder aDecoder: NSCoder) {
        showTouchIDButton = false
        super.init(coder: aDecoder)
    }

    @IBAction open func forgotPasscodeButtonPressed() {
        passcodeValidationDelegate?.showForgotPasscodeScreen()
    }
    @IBAction open func touchIDButtonPressed() {
        self.disableUIElementsWhileProcessing()
        
        self.passcodeValidationDelegate?.unlockWithTouchID() { [weak self] result in
            self?.nextButton?.isHidden = false
            log(verbose: "touchIDResult: \(result)")
            
            switch result {
            case .userCancelled:
                self?.enableUIElementsForUserInput()
                
            case .unavailable:
                self?.enableUIElementsForUserInput()
                self?.removeTouchIDAuthentication()
                
            default:
                log(verbose: "touchIDResult: \(result); Nothing to change on the UI")
            }
        }
    }
    

    
    @objc
    internal func textDidChange() -> Bool {
        guard let passcodeString = (passcodeTextView?.textField?.text as NSString?) else {
            return false
        }
        guard let touchIDBttn = touchIDButton else {
            return false
        }
        
        if passcodeString != "" {
            self.nextButton?.isHidden = false
            self.nextButton?.isEnabled = true
            
            if self.showTouchIDButton {
                touchIDBttn.isHidden = true
                touchIDBttn.isEnabled = false
            }
            return true
        } else {
            if self.showTouchIDButton {
                touchIDBttn.isHidden = false
                touchIDBttn.isEnabled = true
            }
            self.nextButton?.isEnabled = false
            self.nextButton?.isHidden = true
            self.passcodeTextView?.textField?.isSecureTextEntry = true
        }
        return false
    }
    
    override func handleApplicationWillEnterForeground() {
        _ = textDidChange()
    }
    
    override func disableUIElementsWhileProcessing() {
        self.view.endEditing(true)
        self.nextButton?.isEnabled = false
        self.activityIndicator?.startAnimating()
        self.passcodeTextView?.textField?.disable()
        self.forgotPasscodeButton?.isEnabled = false
        self.forgotPasscodeButton?.alpha = AWColor.disabledAlphaValue
        if showTouchIDButton {
            self.touchIDButton?.isEnabled = false
            self.touchIDButton?.alpha = AWColor.disabledAlphaValue
        }
    }
    
    override func enableUIElementsForUserInput(){
        self.passcodeTextView?.textField?.enable()
        self.nextButton?.isHidden = true
        self.activityIndicator?.stopAnimating()
        self.forgotPasscodeButton?.isEnabled = true
        self.forgotPasscodeButton?.alpha = AWColor.enabledAlphaValue
        if showTouchIDButton {
            self.touchIDButton?.isEnabled = true
            self.touchIDButton?.alpha = AWColor.enabledAlphaValue
        }
    }

    func removeTouchIDAuthentication() {
        self.showTouchIDButton = false
        self.promptTouchID = false
        self.touchIDButton?.isEnabled = false
        self.touchIDButton?.isHidden = true
    }
}
