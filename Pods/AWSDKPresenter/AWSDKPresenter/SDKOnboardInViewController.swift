//
//  SDKSignInViewController.swift
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


class SDKOnboardingViewController: OnboardingViewController {
    
    override func viewDidLoad() {
        
        emailAddressLabel?.textColor = UIColor.black
        
        signInButton?.setTitle(AWSDKLocalizedString("SignIn"), for: UIControlState.normal)
        signInButton?.setTitle(AWSDKLocalizedString(""), for: UIControlState.disabled)
        
        ///Branding
        signInButton?.setTitleColor(UIColor.white, for: UIControlState.normal)
        signInButton?.backgroundColor = AWBrandingManager.sharedInstance.primaryColor
        brandingApplicationLogo = AWBrandingManager.sharedInstance.imageSplashLogo
        activityIndicator?.color = UIColor.white
        super.viewDidLoad()
    }
    
    @IBAction func SignInButtonPressed(_ sender: UIButton) {
        signInButton?.isEnabled = false
        activityIndicator?.startAnimating()
        guard let delegate = self.onboardingDelegate else{
            log(error: "Error: signInDelegate not set")
            return
        }
        
        delegate.onboardUser(onboardedSuccessfully: { [weak self] (success: Bool) in
            if success == false {
                self?.signInButton?.isEnabled = true
                self?.activityIndicator?.stopAnimating()
            }
        })
    }
    
}
