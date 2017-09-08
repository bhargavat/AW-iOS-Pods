//
//  SDKNaviagationController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

//internal protocol DeviceIdiom {
//    func userInterfaceIdiom() -> UIUserInterfaceIdiom
//}

class DeviceIdiom {
    func userInterfaceIdiom() -> UIUserInterfaceIdiom {
        return UIDevice.current.userInterfaceIdiom
    }
}

class SDKNavigationController: UINavigationController {
    internal var deviceIdiom = DeviceIdiom()
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        if deviceIdiom.userInterfaceIdiom() == UIUserInterfaceIdiom.phone {
            return UIInterfaceOrientationMask.portrait
        }
        return UIInterfaceOrientationMask.all
    }
    
    override var shouldAutorotate : Bool {
        if deviceIdiom.userInterfaceIdiom() == UIUserInterfaceIdiom.phone {
            return false
        }
        return true
    }
    override var prefersStatusBarHidden : Bool {
        return true
    }
}
