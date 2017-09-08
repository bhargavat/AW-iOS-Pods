//
//  SDKWindow.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

public enum SDKWindowType: Int {
    case authentication = 100       ///The main window that most screen
    // The keyboard window level is 10000000, and the background blocker view need to be above the keyboard
    case blocker = 10000000         ///jailbreak and blocker views
    case background = 10000001      ///Background blocker view only
}


open class SDKWindow: UIWindow {
    open var windowType: SDKWindowType?
}
