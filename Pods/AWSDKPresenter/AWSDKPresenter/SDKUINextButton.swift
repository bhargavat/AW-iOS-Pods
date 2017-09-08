//
//  SDKUINextButton.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit
import AWLocalization

class SDKUINextButton: UIButton {
    public override func awakeFromNib() {
        super.awakeFromNib()
        self.setTitle(AWSDKLocalization.getLocalizationString("Next"), for: UIControlState.normal)
        self.setTitle("", for: UIControlState.disabled)
        self.backgroundColor = AWBrandingManager.sharedInstance.primaryColor
    }
}
