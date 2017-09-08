//
//  SDKCustomKeyboardController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit
import AWHelpers
import AWLog

/**
 @brief Disable third-party keyboard by swizzling UIApplicationDelgate calls
 
 @description To disable third-party keyboard use the shared instance and call the disableThirdPartyKeyboard() to swizzle the function that is required to decide if third-party keyboard should be enabled or not. With application(_:shouldAllowExtensionPointIdentifier:) swizzled, if the system calls this method then our swizzled function will check to see if the request by the system is UIApplicationExtensionPointIdentifier.keyboard and return false, else call the original function.
 */
internal class SDKCustomKeyboardController: NSObject {

    internal private(set) var allowCustomKeyboards = true
    
    // If the original function is not swizzled because the function was not implemented, we cannot call the original function and this flag prevents that.
    private var didSwizzleOriginalImplementationForDelegate = false
    
    internal static let shared = SDKCustomKeyboardController()

    internal let selectorUIApplicationDelegate = #selector(UIApplicationDelegate.application(_:shouldAllowExtensionPointIdentifier:))
    internal let selectorSwizzleProtocolUIApplicationDelegate = #selector(SDKCustomKeyboardController.swizzled_application(_:shouldAllowExtensionPointIdentifier:))
    internal weak var applicationDelegate = UIApplication.shared.delegate
    private override init() { }
    
    internal func disableCustomKeyboards() {
        guard
            self.allowCustomKeyboards,
            let appDelegate = applicationDelegate
        else {
            log(info: "Attempted to disable third party keyboard when already disabled")
            return
        }
        
        self.swizzleFunction(originalClass: type(of: appDelegate),
                         originalSelector: self.selectorUIApplicationDelegate,
                         newClass: SDKCustomKeyboardController.self,
                         newSelector: self.selectorSwizzleProtocolUIApplicationDelegate)

        if self.hasClassBeenSwizzled() {
            log(info: "Third party keyboard has been disabled")
        } else {
            log(info: "Could not disable third party keyboard")
            self.allowCustomKeyboards = false
        }
    }
    
    /** swap function implmentations */
    // 1. If the class to add to already has the function, then swizzle (swap) the functions for the new class' selector
    // 2. The implmentation was defined by the function and so let's swizzle
    // 3. MethodSwizzleBetweenClasses does checks internall to see if the selector do exist for the classes to swap so we don't recheck it here
    // 4. Doing class_addMethod(toClass, functionFromClass, newSwizzledImplementation, type) does not work. Swapping the implmentation works and since the original function was nil to begin with class_replaceMethod will return nil
    // 5. Method_exchangeImplementations will not work because class_getInstanceMethod return nil for the original class to get a method instance

    private func swizzleFunction(originalClass: AnyClass, originalSelector: Selector, newClass: AnyClass, newSelector: Selector) {
        guard class_getInstanceMethod(originalClass, originalSelector) == nil else {   // (1)
            self.didSwizzleOriginalImplementationForDelegate = true
            MethodSwizzleBetweenClasses(originalClass,
                                        originalSelector,
                                        SDKCustomKeyboardController.self,
                                        newSelector,
                                        false)
            return
        }
        
        let method = class_getInstanceMethod(newClass, newSelector)
        let type = method_getTypeEncoding(method)
        let newSwizzledImplementation = class_getMethodImplementation(newClass, newSelector)
        
        _ = class_replaceMethod(originalClass, originalSelector, newSwizzledImplementation, type)
    }
    
    internal func hasClassBeenSwizzled() -> Bool {

        guard let appDelegate = applicationDelegate else {
                log(info: "Attempted to disable third party keyboard when already disabled")
                return false
        }
        
        let currentImplementationForClass = class_getMethodImplementation(type(of: appDelegate), self.selectorUIApplicationDelegate) //(4), (5)
        let dataProtectionImplementation = class_getMethodImplementation(SDKCustomKeyboardController.self, self.selectorSwizzleProtocolUIApplicationDelegate)
        return currentImplementationForClass == dataProtectionImplementation
    }
    
    @objc
    private func swizzled_application(_ application: UIApplication,
                                      shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplicationExtensionPointIdentifier) -> Bool {
        
        // At the moment only disabled is allowed of keyboard since there is no way to enable third-party keyboard
        if extensionPointIdentifier == UIApplicationExtensionPointIdentifier.keyboard {
            return false
        }
        
        // if this class does not have the original implementation, then there is no original implementation to call
        if self.didSwizzleOriginalImplementationForDelegate {
            return swizzled_application(application, shouldAllowExtensionPointIdentifier: extensionPointIdentifier)
        }
        
        return true
    }
}
