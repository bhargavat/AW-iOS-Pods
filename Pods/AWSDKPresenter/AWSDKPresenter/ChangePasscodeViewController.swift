//
//  ChangePasscodeViewController.swift
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

enum ChangePasscodeProgressStage {
    case validateOldPasscode
    case enterNewPasscode
    case confirmNewPasscode
}

open class ChangePasscodeViewController: BaseViewController, ChangePasscodeViewControllerDelegate {

    // Handles actual change of the passcode and dismissal of change passcode view
    open weak var changePasscodeDelegate: ChangePasscodeViewControllerDelegate?

    // Checks whether old/current passcode is correct
    open weak var delegatePasscodeValidator: PasscodeValidationProtocol?

    // Checks whether the new passcode follows restrictions
    open weak var delegatePasscodeComplianceDetector: PasscodeComplianceProtocol?

    // MARK: UI Properties
    @IBOutlet weak var passcodeTextView: SDKUIPasswordTextView?
    @IBOutlet weak var SSOOnePasscodeLabelView: UIView?
    @IBOutlet open weak var passcodeRestrictionLabel: UILabel?
    @IBOutlet open weak var activityIndicator: UIActivityIndicatorView?
    @IBOutlet open weak var nextButton: UIButton?
    @IBOutlet open weak var cancelButton: UIButton?

    var changePasscodeProgressStage: ChangePasscodeProgressStage = .validateOldPasscode
    var potentialPasscode: String = ""
    open var showSSOPasscodeFooterLabel: Bool = true
    open var showCancel: Bool = false

    override open func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.isHidden = (showCancel == false)
        nextButton?.isHidden = true
        nextButton?.isEnabled = false
        
        switch changePasscodeProgressStage {
        case .validateOldPasscode:
            break
        case .enterNewPasscode:
            cancelButton?.isHidden = false
            cancelButton?.isEnabled = true
            SSOOnePasscodeLabelView?.isHidden = !showSSOPasscodeFooterLabel
            break
        case .confirmNewPasscode:
            cancelButton?.isHidden = false
            cancelButton?.isEnabled = true
            SSOOnePasscodeLabelView?.isHidden = !showSSOPasscodeFooterLabel
            break
        }
    
        passcodeTextView?.textField?.delegate = self        
    }

    //MARK: Delegate Methods
    ///Work back through the stack of change passcode view controller's to the original delagate
    
    // Called by the view controller to tell the delegate to change the passcode
    public func changePasscode(new newPasscode: String?,
                        old oldPasscode: String?,
                        completionHandler:(_ success: Bool, _ error: NSError?) -> Void) {
        self.changePasscodeDelegate?.changePasscode(new: newPasscode,
                                                    old: oldPasscode,
                                                    completionHandler: completionHandler)
    }
    
    // Tells the delegate that the view controller is finished
    // if successful, `success` would be `true`, `errorOpt` would be `nil`
    // if not,`success` would be `true`, `errorOpt` would be some NSError
    public func changePasscodeViewControllerFinished(success: Bool, error errorOpt: NSError?) {
        _ = navigationController?.popViewController(animated: false) ///need to pop each of the three changePasscode VC's
        self.changePasscodeDelegate?.changePasscodeViewControllerFinished(success: success, error: errorOpt)
    }
}
