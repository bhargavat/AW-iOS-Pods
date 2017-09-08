//
//  SDKAuthenticationViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLocalization

open class SDKAuthenticationViewController: AuthenticationViewController {
    
    @IBOutlet weak var contentView: UIControl?
    @IBOutlet weak var scrollView: UIScrollView?
    
    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    var nextButtonMovementHandler: NextButtonMovementController?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        log(verbose: "ViewDidLoad: SDKAuthenticationViewController")
        
        usernameTextField?.delegate = self
        passwordTextView?.textField?.delegate = self
        
        // Localization
        usernameTextField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("Username"),
                                                                      attributes: nil)
        useTokenButton?.setTitle(AWSDKLocalizedString("UseToken"), for: .normal)
        passwordTextView?.textField?.placeholder = AWSDKLocalizedString("Password")
        usernameTextField?.addTarget(self, action: #selector(textDidChange),
                                     for: UIControlEvents.editingChanged)
        passwordTextView?.textField?.addTarget(self, action: #selector(textDidChange),
                                     for: UIControlEvents.editingChanged)
        nextButton?.isEnabled = false
        attemptToAutofillUsernameField()
        
        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error: "nextButtonVerticalConstraintFromBottom not set")
            return
        }
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log(verbose: "ViewWillAppear: SDKAuthenticationViewController")
        ScrollViewHandler.sharedInstance.scrollView = scrollView
        ScrollViewHandler.sharedInstance.viewToScrollTo = nextButton
        
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.promptTouchID { // if were are going to display the touchID prompted then no textFeild should become the first responder
            self.loginWithTouchIDPressed()
            return
        }
        if let usernameTextFieldCount = usernameTextField?.text?.characters.count, usernameTextFieldCount > 0 {
            _ = passwordTextView?.textField?.becomeFirstResponder()
        } else if !lockUsernameTextField {
            _ =  usernameTextField?.becomeFirstResponder()
        }
    }
    
    /** loginWithLoginPressed will call the delegate authenticationDelegate?.login(username, password: password, rememberUser: showRememberMe,workOffline: showWorkOffline) the variables to show remember or work online must be set to show those buttons.
     */
    @IBAction func nextButtonPressed() {
        self.stopObservingApplicationLifecycleNotifications()
        
        var username = ""
        var password = ""
        if let usernameText = usernameTextField?.text {
            username = usernameText
        }
        if let passwordText = passwordTextView?.textField?.text {
            password = passwordText
        }
        if !lockUsernameTextField { ///if already locked, make no changes
            usernameTextField?.disable()
        }
        nextButton?.isEnabled = false        // disable the button
        activityIndicator?.startAnimating()
        passwordTextView?.textField?.disable()
        passwordTextView?.textField?.isSecureTextEntry = true
        passwordTextView?.showHideButton?.isEnabled = false
        passwordTextView?.showHideButton?.alpha = AWColor.disabledAlphaValue
        if showTokenID {
            useTokenButton?.isEnabled = false
            useTokenButton?.alpha = AWColor.disabledAlphaValue
        }
        if showTouchID {
            touchIDButton?.isEnabled = false
            touchIDButton?.alpha = AWColor.disabledAlphaValue
        }
        
        var shouldLockUsernameWhenFinished = false
        if let rememberUsernameString = self.authenticationDelegate?.rememberedUsernameToAutofill(), rememberUsernameString.characters.count > 0 {
            shouldLockUsernameWhenFinished = true
        }
        self.authenticationDelegate?.login(username: username,
                                           password: password,
                                           rememberUser: false,
                                           workOffline: showWorkOffline,
                                           completionHandler: { [weak self] (success: Bool) in
            self?.startObservingApplicationLifecycleNotifications()
            DispatchQueue.main.async { [weak self] in
                self?.lockUsernameTextField = shouldLockUsernameWhenFinished
                if success {
                    log(debug: "login successfull")
                } else {
                    self?.resetValuesToStartStateOfController()
                    self?.displayButtonsCorrectlyAndSetFirstResponder()
                }
            }
        })
    }
    func resetValuesToStartStateOfController() {
        self.activityIndicator?.stopAnimating()
        self.nextButton?.isHidden = true
        self.passwordTextView?.resetTextFieldToDefaultState()
    }
    func displayButtonsCorrectlyAndSetFirstResponder() -> () {
        if !self.lockUsernameTextField {
            self.usernameTextField?.enable()
            _ = self.usernameTextField?.becomeFirstResponder()
        } else {
            _ = self.passwordTextView?.textField?.becomeFirstResponder()
        }

        if self.showTokenID {
            self.useTokenButton?.isEnabled = true
            self.useTokenButton?.alpha = AWColor.enabledAlphaValue
        }
        if self.showTouchID {
            self.touchIDButton?.isHidden = false
            self.touchIDButton?.isEnabled = true
            self.touchIDButton?.alpha = AWColor.enabledAlphaValue
        }
    }


    func textDidChange() {
        var makeNextButtonActive = false

        guard let usernameText = usernameTextField?.text, let passwordText = passwordTextView?.textField?.text else {
            log(error: "Storyboard's username or password text field is nil")
            return
        }
        if usernameText.isEmpty == false && passwordText.isEmpty == false {
            if showTouchID {
                touchIDButton?.isHidden = true
                touchIDButton?.isEnabled = false
            }

            makeNextButtonActive = true
        } else {
            touchIDButton?.isHidden = !showTouchID
            touchIDButton?.isEnabled = showTouchID
            passwordTextView?.textField?.isSecureTextEntry = true
        }
        nextButton?.isEnabled = makeNextButtonActive
    }
    
    @IBAction override open func workOfflinePressed(_ sender: AnyObject) {
        let btn = sender as! UIButton
        btn.isSelected = !btn.isSelected
    }

    override func handleApplicationDidEnterBackground() {
        self.resetValuesToStartStateOfController()
    }
    
    override func handleApplicationWillEnterForeground() {
        self.attemptToAutofillUsernameField()
        self.displayButtonsCorrectlyAndSetFirstResponder()
        self.textDidChange()
    }
    //MARK: UITextFieldDelegate Methods
    ///Implemented to enable tabbing through UITextFields
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let passwordTextField : UITextField = passwordTextView?.textField else { return false }
        
        if nextButton?.isEnabled == true {
            nextButtonPressed()
            return true
        } else if textField == usernameTextField {
            _ = passwordTextView?.textField?.becomeFirstResponder()
        } else if textField == passwordTextField {
            _ = usernameTextField?.becomeFirstResponder()
        }
        return false
    }
}
