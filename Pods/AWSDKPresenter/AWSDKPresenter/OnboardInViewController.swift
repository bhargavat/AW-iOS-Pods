//
//  SignInViewController.swift
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


class OnboardingViewController: BaseViewController {
    
    open weak var onboardingDelegate: OnboardingViewControllerDelegate?
    open var emailAddress: String? = nil
    @IBOutlet var backgroundView: UIView? ///for the background color theming
    @IBOutlet weak var emailAddressLabel: UILabel?
    @IBOutlet weak var signInButton: UIButton?
    @IBOutlet weak var secondayAppLogoWithText: UIImageView?
    @IBOutlet weak open var activityIndicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        emailAddressLabel?.text = emailAddress
        super.viewDidLoad()
    }
    
}
