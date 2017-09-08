//
//  BaseViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit
import AWHelpers
import AVFoundation

open class BaseViewController : UIViewController, UITextFieldDelegate {
    
    @IBOutlet open weak var appLogoOutlet: UIImageView?
    @IBOutlet open weak var backgroundImageViewOutlet: UIImageView?
    @IBOutlet open weak var centerViewOutlet: SDKUICenterView?
    
    private var _brandingApplicationLogo: UIImage? = nil
    /**
     If not set directly, this variable will attempt to return the default image app logo defined by AWBrandingManager of property imageAppLogo
     */
    var brandingApplicationLogo: UIImage? {
        get {
            if let color = _brandingApplicationLogo {
                return color
            } else {
                return AWBrandingManager.sharedInstance.imageAppLogo
            }
        } set {
            _brandingApplicationLogo = newValue
        }
    }
    private var _brandingBackgroundColor: UIColor? = nil
    /**
     If set when viewDidLoad is called, the background color will be set with the set value. If nothing is set then no color is applied
     */
    var brandingBackgroundColor: UIColor? {
        get {
            if let color = _brandingBackgroundColor {
                return color
            } else {
                return nil
            }
        } set {
            _brandingBackgroundColor = newValue
        }
    }
    var animatedBrandingUpdate = false
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.updateBranding()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateBranding),
                                               name: NSNotification.Name(rawValue: AWBrandingManager.AWNotificationBrandingDidUpdate),
                                               object: nil)
        self.startObservingApplicationLifecycleNotifications()
    }
    
    deinit {
        // NOTE: If removal of observers is moved, make sure that when pushing multiple view controllers on a stack and then going from background to foreground, next buttons from previous views must not be displayed or have text in those text fields. 
        NotificationCenter.default.removeObserver(self)
    }
    
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
    }
    
    func updateBranding() {
        
        let applicationLogo = self.brandingApplicationLogo
        
        if Thread.isMainThread {
            self.setBranding(appLogo: applicationLogo,
                             backgroundImage: nil,
                             backgroundColor: nil, // Currently not supporting Branding for background color
                withAnimation: animatedBrandingUpdate,
                completionHandler: nil)
        } else {
            DispatchQueue.main.async { [weak self] in
                var willAnimate = false
                if let animateBranding = self?.animatedBrandingUpdate {
                    willAnimate = animateBranding
                }
                self?.setBranding(appLogo: applicationLogo,
                                  backgroundImage: nil,
                                  backgroundColor: nil, // Currently not supporting Branding for background color
                    withAnimation: willAnimate,
                    completionHandler: nil)
            }
        }
    }
    func setBranding(appLogo: UIImage?,
                     backgroundImage: UIImage?,
                     backgroundColor: UIColor?,
                     withAnimation: Bool,
                     completionHandler: ((Bool)->Void)? = nil) {
        if withAnimation {
            UIView.animate(withDuration: 0.75, animations: {
                self.backgroundImageViewOutlet?.image = backgroundImage
                self.appLogoOutlet?.image = appLogo
                if backgroundColor != nil {
                    self.view.backgroundColor = backgroundColor
                }
                completionHandler?(true)
            })
            return
        } else {
            self.backgroundImageViewOutlet?.image = backgroundImage
            self.appLogoOutlet?.image = appLogo
            if backgroundColor != nil {
                self.view.backgroundColor = backgroundColor
            }
            completionHandler?(true)
        }
        
    }
    
    func checkForCameraPermissions() -> Bool {
        let authorizationStatus: AVAuthorizationStatus =  AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch authorizationStatus {
        case AVAuthorizationStatus.authorized:
            log(debug: "Application has permission to use the camera")
            return true
        case AVAuthorizationStatus.notDetermined:
            log(debug: "AVAuthorizationStatus has not been deteremined, system will ask for permission to use the camera")
            ///Do nothing, allow system to ask for permission
            return true
        default:
            log(debug: "Application camera permission has been denied, We will prompt asking for user to change permissions")
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let settingsAction: UIAlertAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else { return }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if UIApplication.shared.openURL(settingsUrl) {
                        log(debug: "Device Settings successfuly opened")
                    } else {
                        log(error: "ERROR: Device Settings failed to  opened")
                    }
                }
            }
            
            _ = KeyWindowAlert(title: "Enable Camera Access", message: "This application does not have access to your camera. To enable access, tap Settings and turn on Camera", actions: [cancelAction, settingsAction]).show()
            return false
        }
    }
}

extension BaseViewController {
    //** Override this method and call it when it is necessary to enable UI elements */
    func enableUIElementsForUserInput() {
        //override in view controller classes
    }
    
    //** Override this method and call it when it is necessary to disable UI elements */
    func disableUIElementsWhileProcessing() {
        //override in view controller classes
    }
}

extension BaseViewController {
    func handleApplicationDidEnterBackground() {
        //Override this for child view controllers if needed
    }
    
    func handleApplicationWillEnterForeground() {
        //Override this for child view controllers if needed
    }
    
    func startObservingApplicationLifecycleNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationDidEnterBackground),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationWillEnterForeground),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
    }
    func stopObservingApplicationLifecycleNotifications() {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
    }
}


//MARK:- Rotation Support
extension BaseViewController {
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) in
            self.centerViewOutlet?.setNeedsUpdateConstraints()
        }){(UIViewControllerTransitionCoordinatorContext) in}
    }
}
