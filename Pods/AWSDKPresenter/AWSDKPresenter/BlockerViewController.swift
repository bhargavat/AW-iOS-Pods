//
//  BlockerViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

open class BlockerViewController: BaseViewController {
        
    @IBOutlet open weak var blockerMessageLabel: UILabel?
    
    open var blockerMessage: String = "SDK Message"
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        blockerMessageLabel?.text = blockerMessage
    }
}
