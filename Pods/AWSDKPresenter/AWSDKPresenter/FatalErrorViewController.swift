//
//  FatalErrorViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLocalization

class FatalErrorViewController: BaseViewController {
    
    open weak var fatalErrorDelegate: FatalErrorViewControllerDelegate?
    
    @IBOutlet open weak var restartButton: UIButton?
    @IBOutlet open weak var errorTitleLabel: UILabel?       ///"An error occured"
    @IBOutlet open weak var errorDescriptionLabel: UILabel? ///"For more information, please contact your IT administrator"
    @IBOutlet open weak var errorCodeLabel: UILabel?        ///"Error code: {#%*@}"
    open var allowRestart: Bool = false
    open var errorCodeText: String? = nil
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        restartButton?.isHidden = !allowRestart
        restartButton?.isEnabled = allowRestart
        errorTitleLabel?.text = AWSDKLocalizedString("AnErrorOccured")
        errorDescriptionLabel?.text = AWSDKLocalizedString("ContactYourAdministrator")
        if let errorCode: String = errorCodeText {
            errorCodeLabel?.text = AWSDKLocalizedString("ErrorCode") + " \(errorCode)"
        } else {
            errorCodeLabel?.isHidden = true /// hide if we have no error code to display
        }
    }
    
    
    @IBAction func restartButtonPressed() {
        restartButton?.isEnabled = false
        restartButton?.alpha = AWColor.disabledAlphaValue
        guard let _: FatalErrorViewControllerDelegate = fatalErrorDelegate else {
            log(error: "ERROR: No FatalErrorViewControllerDelegate has been set: cannot restart")
            restartButton?.isHidden = true
            return
        }
        fatalErrorDelegate?.restart()
    }
}
