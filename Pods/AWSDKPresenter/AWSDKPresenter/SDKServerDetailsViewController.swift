//
//  SDKServerDetailsViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLocalization

internal class SDKServerDetailsViewController: ServerDetailsViewController {
    
    @IBOutlet weak var nextButtonVerticalConstraintFromBottom: NSLayoutConstraint?
    @IBOutlet weak var scrollView: UIScrollView?
    var nextButtonMovementHandler: NextButtonMovementController?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log(verbose: "ViewDidLoad: SDKServerDetailsViewController")
        
        serverURLTextField?.placeholder = AWSDKLocalization.getLocalizationString("ServerURL")
        serverGroupIDTextField?.placeholder = AWSDKLocalization.getLocalizationString("GroupID")
        scanForQRCodeButton?.setTitle(AWSDKLocalization.getLocalizationString("ScanQRCode"), for: UIControlState.normal)
        
        nextButton?.isHidden = true
        
        guard let constraint = nextButtonVerticalConstraintFromBottom else {
            log(error: "nextButtonVerticalConstraintFromBottom not set")
            return
        }
        nextButtonMovementHandler = NextButtonMovementController(constraint: constraint, callingView: self.view)
        		
        _ = areTextFieldsValid()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log(verbose: "ViewWillAppear: SDKServerDetailsViewController")
        navigationController?.setNavigationBarHidden(true, animated: true)
        ScrollViewHandler.sharedInstance.scrollView = scrollView
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log(verbose: "ViewWillAppear: SDKServerDetailsViewController")
        
        _ = serverURLTextField?.becomeFirstResponder()
        serverURLTextField?.underlinedUnfocused()
        serverGroupIDTextField?.underlinedUnfocused()
    }
    // When ServerDetails is displayed the ScrollViewHandler gets ServerDetail's scrollView and viewToScrollTo objects and the previous window scrollView and viewToScrollTo gets removed. This deinit restores the previous keyWindow scrollView and viewToScrollTo objects by calling viewWillAppear. viewWillAppear is where scrollView and viewToScrollTo are set
    deinit {
        let keyWindow = UIApplication.shared.keyWindow
        if ((keyWindow?.rootViewController as? SDKNavigationController) != nil) {
            let topViewController = (keyWindow?.rootViewController as! SDKNavigationController).topViewController
            if topViewController is SDKAuthenticationViewController {
                let vc = topViewController as! SDKAuthenticationViewController
                vc.viewWillAppear(false)
            }
        }
         NotificationCenter.default.removeObserver(self)
    }
    
    // Mark: Navigational
    @IBAction func unwindToSDKServerDetailsViewController(_ sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? QRViewController {
            if let details = sourceViewController.details {
                serverURLTextField?.text = details.serverURL
                serverGroupIDTextField?.text = details.groupID
            }
            scanForQRCodeButton?.alpha = AWColor.enabledAlphaValue
            scanForQRCodeButton?.isEnabled = true
            // If the user scans a valid QR, this will make `OK` clickable
            _ = self.areTextFieldsValid()
        }
    }
    
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let destinationVC = segue.destination as? QRViewController {
            destinationVC.scannerType = QRScannerType.ServerDetails
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "openQRScanner" {
            let cameraAccess = checkForCameraPermissions()
            if cameraAccess {
                scanForQRCodeButton?.isEnabled = false
                scanForQRCodeButton?.alpha = AWColor.disabledAlphaValue
            }
            return cameraAccess
        }
        return true
    }
}
