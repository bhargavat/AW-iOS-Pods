//
//  SDKWindowManager.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

protocol SDKWindowProtocol {
    func createWindow(_ frame: CGRect) -> SDKWindow
}
extension SDKWindowManager: SDKWindowProtocol {
    func createWindow(_ frame: CGRect) -> SDKWindow {
        return SDKWindow(frame: frame)
    }
}

class SDKWindowManager {
    fileprivate let ANIMATION_SPEED = 0.3
    // A dictionary is used to keep track of when a window has been displayed to the user
    internal var windows = NSMutableDictionary()
    
    internal static let shared = SDKWindowManager()
    
    // A protocol used primarily for unit test
    internal var sdkWindowProtocol: SDKWindowProtocol? = nil
    
    private var queueNextPresentationToExecute: (()->Void)? = nil
    var blockPresentationOfNewViewController: Bool = false {
        willSet {
            if newValue == false {
                self.queueNextPresentationToExecute?()
                self.queueNextPresentationToExecute = nil
            }
        }
    }
    
    private init() { }
    
    // During unit tests, we cannot call UIApplication.sharedApplication().window[0] or the program will crash
    fileprivate var _dummyWindow: UIWindow? = nil
    internal var applicationWindow: UIWindow {
        get {
            if _dummyWindow == nil {
                return UIApplication.shared.windows[0]
            }
            return _dummyWindow!
        }
        set {
            _dummyWindow = newValue
        }
    }
    
    /**
     Display the view controller. If the view controller should be put in a navigation controller, pass the navigation controller as a paramter.
     If the top most view controller is the same as the one you are pushing then false is returned.
     If the view controller can be added to the navigation stack or window, then true is returned.
     */
    @discardableResult func present(viewController: UIViewController,
                                   windowType:SDKWindowType,
                                   navigationStack: UINavigationController? = nil,
                                   animationType: SDKAnimationType = SDKAnimationType.none) -> Bool {
        
        self.prepareToPresent(viewController: viewController, navigationStack: navigationStack)
        
        let blockToPresentViewController = { [weak self] in
            guard
                let weakSelf = self
            else {
                log(error: "Could not present view controller because self pointer is no longer valid")
                return
            }
            let applicationWindowFrame = weakSelf.applicationWindow.frame
            let newWindowFrameRect: CGRect
            // If the device's orientation is landscape and is iPhone or iPod touch then we need to fix the dimensions
            // Landscape mode produces a screen width with a value that is bigger than height so they need to be swapped since the animateWindow function will present from bottom of the screen to position (0,0) of the screen
            // Also need to make the window off screen, hence why the y position is the height
            switch UIDevice.current.userInterfaceIdiom {
                
            case .phone where UIScreen.main.bounds.width > UIScreen.main.bounds.height:
                newWindowFrameRect = CGRect(x: 0, y: applicationWindowFrame.height, width: applicationWindowFrame.height, height: applicationWindowFrame.width)
                
            default:
                newWindowFrameRect = CGRect(x: 0, y: applicationWindowFrame.height, width: applicationWindowFrame.width, height: applicationWindowFrame.height)
            }
            
            let sdkWindow = weakSelf.createAndMakeKeyWindowVisible(windowType: windowType, windowFrame: newWindowFrameRect)
            
            // Must make screen portrait for iphone or ipod touch so that the animation will know what the orientation should be when displaying the view controller.
            // NOTE: setting this before the creation of the window will not cause iOS to change the frame dimensions immediately. iOS still showed the same dimensions of being in landsape when checking the window frame 
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
                let value = UIInterfaceOrientation.portrait.rawValue
                UIDevice.current.setValue(value, forKey: "orientation")
            }
            
            if navigationStack != nil {
                if( weakSelf.isWindowCurrentlyDisplayed(windowType) == false) {
                    sdkWindow.rootViewController = navigationStack
                    weakSelf.animateWindow(sdkWindow, rect: newWindowFrameRect, animationType: animationType)
                }
                navigationStack?.pushViewController(viewController, animated: true)
            }
            else {
                sdkWindow.rootViewController = viewController
                weakSelf.animateWindow(sdkWindow, rect: newWindowFrameRect, animationType: animationType)
            }
            
            if weakSelf.isWindowCurrentlyDisplayed(windowType) == false {
                weakSelf.windows.setObject(sdkWindow, forKey: windowType.rawValue as NSCopying)
            }
            navigationStack?.interactivePopGestureRecognizer?.isEnabled = false
        }
        
        if self.blockPresentationOfNewViewController {
            self.queueNextPresentationToExecute = blockToPresentViewController
        } else {
            blockToPresentViewController()
        }
        
        return true
    }
    
    // Pop view controllers from stack, if there is only one view controller left and pop is called, then dismiss the window
    @discardableResult open func pop(fromNavigation navigationController: UINavigationController) -> Bool {
        if (navigationController.viewControllers.count > 1) {
            log(info: "Attempt will be made to pop view controller from navigation stack")
            log(verbose: "Number of view controllers left on stack is \(navigationController.viewControllers.count)")
            DispatchQueue.main.async(execute: { 
                navigationController.popViewController(animated: true)
                log(info: "Did pop view controller from navigation stack")
            })
            return true
        }
        return false
    }
    
    // Dismiss only the airwatchWindow which houses the navigation stack for authentication, passcodevalidation, createpasscode, and changepasscode
    func dismiss(_ windowType: SDKWindowType, animationType: SDKAnimationType = .none) {
        log(verbose: "Will attempt to dismiss window \(windowType)")
        if let window = getWindow(windowType) {
            log(debug: "\(windowType) exists and will be dismissed")
            
            windows.removeObject(forKey: windowType.rawValue)
            
            if let keys = windows.allKeys as? [Int], keys.count > 0 {
                // There is a SDK window which is the key window, make top most SDK app window the key window
                var topMostWindowValue = 0
                keys.forEach({ (key: Int) in
                    if key > topMostWindowValue {
                        topMostWindowValue = key
                    }
                })
                guard let topWindowType = SDKWindowType(rawValue: topMostWindowValue),
                      let topWindow = getWindow(topWindowType) else {
                    return
                }
                topWindow.makeKey()
            }else {
                // There are no more windows presented by the SDK, make app window the key window
                if windowType == SDKWindowType.authentication {
                    let appWindow = UIApplication.shared.windows.first
                    appWindow?.makeKey()
                }
            }
            
            DispatchQueue.main.async(execute: {
                if animationType == .none {
                    let rect = self.applicationWindow.frame
                    window.frame = CGRect(x: 0, y: rect.size.height, width: rect.size.width, height: rect.size.height)
                } else if animationType == .modal {
                    let rect = window.frame
                    UIView.animate(withDuration: self.ANIMATION_SPEED, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                        window.frame = CGRect(x: rect.origin.x, y: rect.origin.y+rect.size.height, width: rect.size.width, height: rect.size.height)
                    }) { (bool) in
                        log(verbose: "Animation ended for \(window)")
                    }
                }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
                log(info: "The window \(windowType) was dismissed")
            })
        }else {
            log(info: "Attempted to dismiss window not displayed")
        }
        
    }
    
    internal func getWindow(_ windowType: SDKWindowType) -> SDKWindow? {
        return windows.object(forKey: windowType.rawValue) as? SDKWindow
    }
    internal func isWindowCurrentlyDisplayed(_ windowType: SDKWindowType) -> Bool {
        if (windows.object(forKey: windowType.rawValue) != nil) {
            return true
        }
        return false
    }
}

extension SDKWindowManager {
    fileprivate func prepareToPresent(viewController: UIViewController, navigationStack: UINavigationController?) -> Void {
        guard let navigationStack = navigationStack else { return }
        
        /**
         * If the navigationStack is valid, we will check its viewControllers to see if there is any duplicate inside it to prevent
         * identical items. What this function is doing is that we will search the the type of the new viewController in current
         * array to see if there is already one that shares the same type, and we will remove that one and all viewControllers behind
         * it in the array. Example:
         *
         * view controller that needs to be presented : SDKPasscodeValidationViewController
         *
         * array of viewcontrollers in navigationStack: [SDKLoadingViewController,
         *                                               SDKPasscodeValidationViewController,
         *                                               SDKForgotPasscodeViewController,
         *                                               SDKAuthenticationViewController]
         *
         * there is already a SDKPasscodeValidationViewController in the array, so after this function, the arary will be changed to:
         *
         * array of viewcontrollers in navigationStack: [SDKLoadingViewController]
         *
         * This way we can guarantee:
         *  1. There is no duplicated view controllers in our navigationStack
         *  2. The view controller that needs to be presented will always be presented with the right position in the navigationStack
         *
         **/
        
        let viewControllers = navigationStack.viewControllers.prefix { type(of: $0) != type(of: viewController) }
        navigationStack.viewControllers.enumerated().forEach { index, element in
            if viewControllers.contains(element), index < viewControllers.count { return }
            navigationStack.viewControllers.remove(at: index)
        }
    }
    
    /**
     If a window has not been created, then it will be created. If the window has been created, get that window and return it
     In either case the window returned will be made the key window and visible
     */
    fileprivate func createAndMakeKeyWindowVisible(windowType: SDKWindowType, windowFrame: CGRect) -> SDKWindow {
        let window = self.windows.object(forKey: windowType.rawValue) as? SDKWindow
        var sdkWindow: SDKWindow
        if(window != nil) {
            window!.makeKey()
            window!.makeKeyAndVisible()
            return window!
        }
        
        if self.sdkWindowProtocol == nil{
            sdkWindow = SDKWindow(frame: windowFrame)
        }else {
            sdkWindow = sdkWindowProtocol!.createWindow(windowFrame)
        }
        sdkWindow.makeKey()
        sdkWindow.makeKeyAndVisible()
        sdkWindow.windowLevel = UIWindowLevelStatusBar + CGFloat(windowType.rawValue)
        sdkWindow.windowType = windowType
        log(debug: "Window object creted is \(sdkWindow) of type \(String(describing: sdkWindow.windowType))")
        log(debug: "The window level is \(sdkWindow.windowLevel)")
        
        return sdkWindow
    }
    fileprivate func animateWindow(_ window: SDKWindow, rect: CGRect, animationType: SDKAnimationType, completionHandler: ((Bool) -> ())? = nil) {
        let windowDimensions = CGRect(
            x: rect.origin.x,
            y: rect.size.height,// We want to put the new window where the user can't see it to animate it
            width:rect.size.width,
            height:rect.size.height)
        
        DispatchQueue.main.async(execute: {
            let deviceWidth = windowDimensions.size.width
            let deviceHeight = windowDimensions.size.height
            
            switch animationType {
            case .none:
                window.frame = CGRect(x: 0, y: 0, width: deviceWidth, height: deviceHeight)
                log(debug: "Animation None finished for window \(window)")
                completionHandler?(true)
            case .modal:
                UIView.animate(withDuration: self.ANIMATION_SPEED, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    window.frame = CGRect(x: 0, y: 0, width: deviceWidth, height: deviceHeight)
                }) { (bool) in
                    log(debug: "Animation Modal finished for window \(window)")
                    completionHandler?(true)
                }
            }
        })
    }
}
