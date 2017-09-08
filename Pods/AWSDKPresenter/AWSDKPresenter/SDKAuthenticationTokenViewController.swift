//
//  SDKAuthenticationTokenViewController.swift
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

class SDKAuthenticationTokenViewController: AuthenticationTokenViewController {
    
    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    var nextButtonMovementHandler: NextButtonMovementController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        useUsernamePasswordButton?.setTitle(AWSDKLocalizedString("UseUserNamePassword"), for: UIControlState.normal)
        tokenTextField?.placeholder = AWSDKLocalizedString("Token")
        
        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error: "nextButtonVerticalConstraintFromBottom not set")
            return
        }
        
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tokenTextField?.underlinedUnfocused() //add the underline
    }
    
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        guard let token: String = tokenTextField?.text else {
            log(error: "tokenTextField does not exist")
            return
        }
        
        self.stopObservingApplicationLifecycleNotifications()
        self.disableUIElementsWhileProcessing()
        
        self.authenticationDelegate?.login(authenticationToken: token, completionHandler: { [weak self] (success: Bool) in
            guard let weakSelf = self else {
                log(debug: "Attempted to access self in completion handler of login with token when self is no longer available")
                return
            }
            weakSelf.startObservingApplicationLifecycleNotifications()
            // TODO: Currently users are not allowed to go back when authenticating with token based auth. Will need to revise this code to re-enable these objects when the view re-appears because user requested to go back on the navigation stack 
            if success {
                log(debug: "Successfully logged in with authentication token")
            } else {
                DispatchQueue.main.async {
                    weakSelf.enableUIElementsForUserInput()
                }
            }
        })
    }
    
    override func enableUIElementsForUserInput() {
        self.cancelButton?.isEnabled = true
        self.tokenTextField?.isEnabled = true
        self.activityIndicator?.stopAnimating()
        self.nextButton?.isEnabled = true
        self.useUsernamePasswordButton?.isEnabled = true
        if self.canUseCameraToScanQRCode {
            self.scanQRCodeButton?.alpha = AWColor.enabledAlphaValue
            self.scanQRCodeButton?.isEnabled = true
        }
        
        self.tokenTextField?.isEnabled = true
    }
    
    override func disableUIElementsWhileProcessing() {
        self.cancelButton?.isEnabled = false
        self.useUsernamePasswordButton?.isEnabled = false
        self.tokenTextField?.isEnabled = false
        self.nextButton?.isEnabled = false
        if self.canUseCameraToScanQRCode {
            self.scanQRCodeButton?.alpha = AWColor.disabledAlphaValue
            self.scanQRCodeButton?.isEnabled = false
        }
        
        self.activityIndicator?.startAnimating()
    }
    
    // Mark: Navigational
    @IBAction func unwindToSDKAuthenticationTokenViewController(_ sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? QRViewController {
            if let tokenCode = sourceViewController.tokenCode {
                tokenTextField?.text = tokenCode
            }
            
            self.scanQRCodeButton?.alpha = AWColor.enabledAlphaValue
            self.scanQRCodeButton?.isEnabled = true
            _ = self.textDidChange()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationVC = segue.destination as? QRViewController {
            destinationVC.scannerType = QRScannerType.TokenCode
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "tokenOpenQRScanner" {
            let cameraAccess = checkForCameraPermissions()
            if cameraAccess {
                self.scanQRCodeButton?.isEnabled = false
                self.scanQRCodeButton?.alpha = AWColor.disabledAlphaValue
            }
            return cameraAccess
        }
        return true
    }
    
    override func handleApplicationDidEnterBackground() {
        self.tokenTextField?.text = ""
        self.nextButton?.isHidden = true
    }

}
