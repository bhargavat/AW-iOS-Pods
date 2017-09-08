//
//  SDKJailbrokenViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWLocalization
import Foundation
import UIKit

open class SDKJailbrokenViewController: JailbrokenViewController{
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        imageJailbroken = AWResource.getImage("JailBreak")
        stringMessageDisplayedOnViewController = AWSDKLocalization.getLocalizationString("AWCompromiseBlockerMessageWhenNoNetwork")
    }

    override open func viewDidLoad() {
        outletJailbrokenMessage?.textColor = UIColor.black
        super.viewDidLoad()
    }
}
