//
//  UserLoginViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWLocalization
import Foundation
import UIKit

open class AuthenticationViewController: BaseViewController {

    open weak var authenticationDelegate: AuthenticationViewControllerDelegate?
    open weak var settingsDelegate: ViewControllerDisplaySettingsDelegate?
    open weak var cancelDelegate: ViewControllerDisplayCancellationDelegate?

    @IBOutlet open weak var usernameTextField: SDKUITextField?
    @IBOutlet open weak var passwordTextView: SDKUIPasswordTextView?

    @IBOutlet weak var useTokenButton: UIButton?
    @IBOutlet open weak var nextButton: UIButton?
    @IBOutlet open weak var touchIDButton: UIButton?
    @IBOutlet open weak var cancelButton: UIButton?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    @IBOutlet open weak var usernameTextFieldLockedIcon: UIImageView?

    open var showCancel: Bool
    open var showTouchID: Bool = false
    open var promptTouchID: Bool = false
    open var showTokenID: Bool
    open var showSettingsGear: Bool
    open var lockUsernameTextField: Bool = false
    open var showWorkOffline: Bool
    
    required public init?(coder aDecoder: NSCoder) {
        showCancel = false
        showTouchID = false
        lockUsernameTextField = false
        showWorkOffline = false
        showSettingsGear = true
        showTokenID = false
        super.init(coder: aDecoder)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.isHidden   = !showCancel
        nextButton?.isEnabled = false
        nextButton?.isHidden = true
        usernameTextField?.autocorrectionType = UITextAutocorrectionType.no
        usernameTextField?.addTarget(self, action: #selector(shouldDisplayNextButton), for: UIControlEvents.editingChanged)
        passwordTextView?.textField?.addTarget(self, action: #selector(shouldDisplayNextButton), for: UIControlEvents.editingChanged)
        
        useTokenButton?.isHidden = !showTokenID
        useTokenButton?.isEnabled = showTokenID
        touchIDButton?.isHidden = !showTouchID
        touchIDButton?.isEnabled = showTouchID
    }

    // loginWithTouchIDPressed will call authenticationDelegate?.loginWithTouchIDPressed directly so that the delegate can handle authentication
    @IBAction open func loginWithTouchIDPressed() {
        self.disableUIElementsWhileProcessing()
        
        self.authenticationDelegate?.unlockWithTouchID() { [weak self] result  in
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

    // settingsButtonPressed will call settingsDelegate?.showServerDetails directly so that the delegate can handle the display of server details
    @IBAction open func settingsButtonPressed() {
        settingsDelegate?.showServerDetails()
    }

    // when this button is selected, showWorkOffline variable will have the value regarding to remember or not
    @IBAction open func workOfflinePressed(_ sender: AnyObject) {
        let btn = sender as! UIButton
        btn.isSelected = !btn.isSelected
        showWorkOffline = btn.isSelected
        
    }

    // cancelButtonPressed will call the cancelDelegate?.cancelViewController directly so that the delgate can handle the cacelation of authentication
    @IBAction open func cancelButtonPressed() {
        cancelDelegate?.cancelViewController()
    }
    
    override open func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationVC = segue.destination as? SDKAuthenticationTokenViewController {
            guard let delegate = authenticationDelegate else {
                log(error: "ERROR:: no authenticationDelegate has been set!")
                return
            }
            destinationVC.authenticationDelegate = delegate
        }
    }
    
    func attemptToAutofillUsernameField() {
        guard let delegate = authenticationDelegate  else {
            log(error: "ERROR:: no authenticationDelegate has been set!")
            return
        }
        if let rememberedUsernameToAutofill: String = delegate.rememberedUsernameToAutofill(), rememberedUsernameToAutofill != ""  {
            lockUsernameTextField = true
            usernameTextFieldLockedIcon?.isHidden = false
            usernameTextField?.text = rememberedUsernameToAutofill
            usernameTextField?.isEnabled = false
            usernameTextField?.alpha = AWColor.disabledAlphaValue
        }
    }
    
    @objc
    open func shouldDisplayNextButton() -> Bool {
        guard let usernameString = usernameTextField?.text, let passwordString = passwordTextView?.textField?.text else {
            return false
        }
        
        let areBothTextFieldsNotEmpty = usernameString != "" && passwordString != ""
        self.nextButton?.isHidden = !areBothTextFieldsNotEmpty
        self.nextButton?.isEnabled = areBothTextFieldsNotEmpty
        return areBothTextFieldsNotEmpty
    }
    
    override func disableUIElementsWhileProcessing() {
        self.view.endEditing(true)
        self.activityIndicator?.startAnimating()
        self.usernameTextField?.disable()
        self.passwordTextView?.textField?.disable()
        self.useTokenButton?.isEnabled = false
        self.useTokenButton?.alpha = AWColor.disabledAlphaValue
        self.nextButton?.isEnabled = false
        if self.showTouchID {
            self.touchIDButton?.isEnabled = false
            self.touchIDButton?.alpha = AWColor.disabledAlphaValue
        }
    }
    
    override func enableUIElementsForUserInput() {
        self.activityIndicator?.stopAnimating()
        self.usernameTextField?.enable()
        self.passwordTextView?.textField?.enable()
        self.useTokenButton?.alpha = AWColor.enabledAlphaValue
        self.nextButton?.isEnabled = false
        self.nextButton?.isHidden = true
        self.useTokenButton?.isEnabled = showTokenID
        if self.showTouchID {
            self.touchIDButton?.isEnabled = true
            self.touchIDButton?.alpha = AWColor.enabledAlphaValue
        }
    }
    
    func removeTouchIDAuthentication() {
        self.showTouchID = false
        self.promptTouchID = false
        self.touchIDButton?.isEnabled = false
        self.touchIDButton?.isHidden = true
    }
}
