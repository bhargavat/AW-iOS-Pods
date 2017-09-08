//
//  SDKUIPasswordTextView.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit
import AWLocalization

public class SDKUIPasswordTextView: UIView {
    
    @IBOutlet open weak var textField : SDKUITextField?
    @IBOutlet open weak var showHideButton : SDKUIShowHideButton?
    
    ///a view that will provides a background for the right half of the show hide button
    ///this is needed because the button size is 44x44 but we only want to provide a background from where the icon is until the end of the textfield
    @IBOutlet open weak var rightButtonBackgroundView: UIView?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        self.textField?.isSecureTextEntry = true
        self.textField?.autocorrectionType = UITextAutocorrectionType.no
        self.textField?.attributedPlaceholder = NSAttributedString(string:AWSDKLocalization.getLocalizationString("Password"))
        showHideButton?.addTarget(self, action: #selector(showHideButtonPressed), for: UIControlEvents.touchUpInside)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(shouldDisplayShowHideButton),
                                               name: .UITextFieldTextDidChange,
                                               object: nil)
        showHideButton?.buttonState = .HideButton
    }
    
    @objc
    open func showHideButtonPressed(_ sender: AnyObject) {
        switch (showHideButton?.buttonState)! as SDKUIShowHideButtonState {
        case .ShowPassword:
            showHideButton?.buttonState = .HidePassword
            textField?.updateSecureEntry(isSecure: true)
        case .HidePassword:
            showHideButton?.buttonState = .ShowPassword
            textField?.updateSecureEntry(isSecure: false)
        default: break
        }
    }
    
    @objc
    func shouldDisplayShowHideButton() {
        if textField?.text?.characters.count == 0 {
            showHideButton?.buttonState = .HideButton
            rightButtonBackgroundView?.isHidden = true
        }
        else {
            if(showHideButton?.buttonState == .HideButton) {
                rightButtonBackgroundView?.isHidden = false
                showHideButton?.buttonState = .HidePassword
            }
        }
    }
    
    /**
     Marks the textfield as enabled, clears text, and hides the button to show/hide the passcode as text.  
     */
    func resetTextFieldToDefaultState() {
        self.textField?.text = ""
        self.textField?.isEnabled = true
        self.textField?.alpha = AWColor.enabledAlphaValue
        self.shouldDisplayShowHideButton()
    }
}
