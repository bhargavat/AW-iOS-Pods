//
//  CreatePasscodeViewController.swift
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

open class CreatePasscodeViewController: BaseViewController, CreatePasscodeViewControllerDelegate  {

    // MARK: Delegates to be implemented and *set* by app level

    // Handles actual creation of passcode and dismissal of create passcode view
    open weak var createPasscodeDelegate: CreatePasscodeViewControllerDelegate?

    // Checks whether the new passcode follows restrictions
    open weak var delegatePasscodeComplianceDetector: PasscodeComplianceProtocol?

    @IBOutlet weak var createPasscodeTextView: SDKUIPasswordTextView?
    @IBOutlet weak var passcodeRestrictionLabel: UILabel?
    @IBOutlet weak var SSOOnePasscodeLabelView: UIView?
    @IBOutlet weak open var nextButton: UIButton?
    @IBOutlet weak open var activityIndicator: UIActivityIndicatorView?    
    @IBOutlet open weak var cancelButton: UIButton?

    open var showSSOPasscodeFooterLabel: Bool = true
    open var showCancel: Bool = false

    override open func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.isHidden = (showCancel == false)
        createPasscodeTextView?.textField?.delegate = self
        SSOOnePasscodeLabelView?.isHidden = !showSSOPasscodeFooterLabel
    }
    
    
    //MARK: Delegate Methods
    ///Work back through the stack of create passcode view controller's to the original delagate
    
    // Called by the view controller to tell the delegate to create the passcode
    public func createPasscode(new passcode: String?,
                        confirm confirmPasscode: String?,
                        completionHandler: @escaping (_ success: Bool, _ error: NSError?) -> Void) {
        guard let delegate = self.createPasscodeDelegate else{
            log(error: "createPasscodeDelegate not set")
            return
        }
        delegate.createPasscode(new: passcode,
                                confirm: confirmPasscode,
                                completionHandler: completionHandler)
    }
    // Tells the delegate that the view controller is finished
    // if successful, `success` would be `true`, `errorOpt` would be `nil`
    // if not,`success` would be `true`, `errorOpt` would be some NSError
    public func createPasscodeViewControllerFinished(success: Bool, error errorOpt: NSError?){
        _ = navigationController?.popViewController(animated: false)
        guard let delegate = self.createPasscodeDelegate else{
            log(error: "createPasscodeDelegate not set")
            return
        }
        delegate.createPasscodeViewControllerFinished(success: success, error: errorOpt)
    }
}

