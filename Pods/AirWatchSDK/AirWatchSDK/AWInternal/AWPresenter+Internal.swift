//
//  AWPresenter+Internal.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWPresentation

@objc
public class AWPresenter: NSObject {

    @objc
    public static func pushAuthenticationUsernamePassword(delegate: AnyObject,
                                                          showRememberUsername: Bool,
                                                          showWorkOnline: Bool,
                                                          showToken: Bool,
                                                          showTouchID: Bool,
                                                          showCancel: Bool,
                                                          showSettingsGear: Bool) -> () {
        guard let delegate = delegate as? AuthenticationViewControllerDelegate else {
            log(error: "The delegate can not be converted to AuthenticationViewControllerDelegate")
            return
        }

        var options:AuthenticationOptions = []
        var touchIDOptions: TouchIDOptions = []
        if showRememberUsername {
            options.insert(AuthenticationOptions.allowRememberUsername)
        }

        if showWorkOnline {
            options.insert(AuthenticationOptions.allowWorkingOffline)
        }

        if showToken {
            options.insert(AuthenticationOptions.allowTokenInput)
        }

        if showTouchID {
            touchIDOptions = TouchIDOptions.allowTouchID
        }
        if showCancel {
            options.insert(AuthenticationOptions.allowCancel)
        }
        if showSettingsGear {
            options.insert(AuthenticationOptions.allowSettingsUpdate)
        }

        AWController.sharedInstance.presenter.presentAuthentication(options: options, touchIDOptions: touchIDOptions, delegate: delegate)
    }
    
    @objc
    public static func displayJailbroken() -> () {
        AWController.sharedInstance.presenter.displayJailbroken()
    }
}
