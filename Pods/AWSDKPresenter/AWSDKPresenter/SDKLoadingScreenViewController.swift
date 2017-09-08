//
//  SDKLoadingScreen.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

open class SDKLoadingScreenViewController: BaseViewController {
    
    override open func viewDidLoad() {
        brandingApplicationLogo = AWBrandingManager.sharedInstance.imageSplashLogo
        super.viewDidLoad()
    }
}
