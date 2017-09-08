//
//  AuthenticationTokenViewController.swift
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

open class AuthenticationTokenViewController: BaseViewController {
    
    open weak var authenticationDelegate: AuthenticationViewControllerDelegate?
    
    @IBOutlet weak var cancelButton: SDKUIBackButton?
    @IBOutlet open weak var tokenTextField: SDKUITextField?
    @IBOutlet open weak var scanQRCodeButton: UIButton?
    @IBOutlet open weak var useUsernamePasswordButton: UIButton?
    @IBOutlet open weak var nextButton: UIButton?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    open var canUseCameraToScanQRCode: Bool = false
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.nextButton?.isEnabled = false
        self.nextButton?.isHidden = true
        self.tokenTextField?.addTarget(self, action: #selector(textDidChange), for: UIControlEvents.editingChanged)
        self.tokenTextField?.delegate = self
        
        // If this key is not found in the app's Info.plist on an iPhone, the iPhone will crash. So if the key/value pair isn't found, disable button to access the camera.
        let reasonForCameraUsage = Bundle.main.infoDictionary?["NSCameraUsageDescription"]
        self.canUseCameraToScanQRCode = !(reasonForCameraUsage == nil)
        if self.canUseCameraToScanQRCode == false {
            self.scanQRCodeButton?.isEnabled = false
            self.scanQRCodeButton?.isHidden = true
        }
    }
    
    @IBAction open func useUsernamePasswordButtonPressed(_ sender: UIButton) {
        _ = navigationController?.popViewController(animated: true)
    }
    
    @IBAction open func cancelButtonPressed(_ sender: UIButton) {
        _ = navigationController?.popViewController(animated: true)
    }

    @objc
    open func textDidChange() -> Bool {
        guard let passcodeString = self.tokenTextField?.text else {
            return false
        }
        
        if passcodeString != "" {
            self.nextButton?.isHidden = false
            self.nextButton?.isEnabled = true
            return true
        } else {
            self.nextButton?.isEnabled = false
            self.nextButton?.isHidden = true
        }
        
        return false
    }
}
