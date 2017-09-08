//
//  SDKTermsAndConditionsViewController.swift
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

class SDKTermsAndConditionsViewController: TermsAndConditionsViewController {
    
    
    override func viewDidLoad() {
        acceptButton?.setTitle(AWSDKLocalizedString("Accept"), for: UIControlState.normal)
        declineButton?.setTitle(AWSDKLocalizedString("DeclineTitle"), for: UIControlState.normal)
        
        ///Branding
        acceptButton?.backgroundColor = AWBrandingManager.sharedInstance.primaryColor
    }
    
    
    @IBAction func acceptButtonTapped(_ sender: UIButton) {
        termsAndConditionsAccountDelegate?.termsAcceptance(accepted: true)
        _ = navigationController?.popViewController(animated: true)
    }
    
    
    @IBAction func declineButtonTapped(_ sender: UIButton) {
        termsAndConditionsAccountDelegate?.termsAcceptance(accepted: false)
        _ = navigationController?.popViewController(animated: true)
    }
}
