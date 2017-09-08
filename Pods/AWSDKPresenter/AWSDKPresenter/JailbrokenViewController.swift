//
//  JailbrokenViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

open class JailbrokenViewController: BaseViewController {
    
    @IBOutlet open weak var outletJailbrokenImage: UIImageView?
    @IBOutlet open weak var outletJailbrokenMessage: UILabel?
    
    open var stringMessageDisplayedOnViewController: String?
    open var imageJailbroken: UIImage?
    
    override open func viewDidLoad() {
        outletJailbrokenImage?.image = imageJailbroken
        outletJailbrokenMessage?.text = stringMessageDisplayedOnViewController
        super.viewDidLoad()
    }
}
