//
//  SDKPresenter.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers

public enum SDKAnimationType {
    case none
    case modal
}

/**

 When the SDK function's are ready to display the appropriate view controller, we need to have specified if there is a custom storyboard use and which animation to use for transitions. If a custom storybaord is used, then subclass the appropriate view controller from AWViewControllers events must be handled such as keyboard, button presses, textfields, hidding specific fuctionality, etc.
 */
open class SDKPresenter {
    fileprivate let ANIMATION_SPEED = 0.3
    fileprivate var storyboard: UIStoryboard?
    
    // Only used for SAML authentication
    fileprivate var navigationController: SDKNavigationController!
    internal let sdkWindowManager: SDKWindowManager
    internal let scrollViewHandler: ScrollViewHandler
    static var backgroundBlocker: UIView = createBlockerView()

    open var isPresenterVisible: Bool {
        get {
            if sdkWindowManager.isWindowCurrentlyDisplayed(SDKWindowType.authentication) ||
                sdkWindowManager.isWindowCurrentlyDisplayed(SDKWindowType.blocker) {
                return true
            }
            return false
        }
    }

    /**
     Constructor for SDK view controllers

     When the SDK function's are ready to display the appropriate view controller, we need to have specified if there is a custom storyboard use and which animation to use for transitions. If a custom storybaord is used, then subclass the appropriate view controller from AWViewControllers events must be handled such as keyboard, button presses, textfields, hidding specific fuctionality, etc.

     SDKAnimationType
     - None
     - Modal
     - Fade

     - Parameter storyBoard: If the storyBoard is nil, then the default SDK view controllers will be present. To specify a custom storybaord, declare in AWSDKDefaultSettings.plist the key CustomStoryBoard and the value should be the name of the storyboard which is in your app's bundle.
     - Parameter animation: If no SDKAnimationType is specified, then the default will be Modal. For certain display* functions a custom animation can be set such as blocker or server details view controllers.
     */

    public convenience init() {
        self.init(storyboard: nil)
    }

    public init(storyboard: UIStoryboard?) {
        self.storyboard = storyboard
        sdkWindowManager = SDKWindowManager.shared

        navigationController = SDKNavigationController()
        navigationController.loadView()
        navigationController.navigationBar.isHidden = true
        scrollViewHandler = ScrollViewHandler.sharedInstance
    }

    //MARK: deinit
    deinit {

    }

    fileprivate func create<A: BaseViewController>(viewControllerType: A.Type) -> A? {
        guard let newViewController = SDKViewControllerGenerator<A>(storyboard: storyboard).viewController else {
            return nil
        }
        return newViewController
    }

    public func disable() -> () {
        self.sdkWindowManager.blockPresentationOfNewViewController = true
    }

    public func enable() -> () {
        self.sdkWindowManager.blockPresentationOfNewViewController = false
    }

    public func reset() -> () {
        DispatchQueue.main.async { [weak self] in
            guard let weakSelf = self else { return }

            weakSelf.enable()
            guard weakSelf.navigationController.viewControllers.count > 0 else {
                weakSelf.displayLoadingScreen()
                return
            }

            if let viewController = weakSelf.navigationController.viewControllers.first,
                viewController is SDKLoadingScreenViewController {
                viewController.view.tag = SDKWindowType.authentication.rawValue
                weakSelf.navigationController.viewControllers = [viewController]
            } else {
                weakSelf.navigationController.viewControllers = []
                weakSelf.reset()
            }
        }
    }

    //MARK: Push calls
    /**
     Show the authentication by using username and password. Also if a custom storyboard is being used, then the appropriate buttons must be handled accordingly.
     */
    @discardableResult open func pushAuthenticationUsernamePassword(delegate: AuthenticationViewControllerDelegate,
                                                                    showWorkOffline: Bool = false,
                                                                    showToken: Bool = false,
                                                                    showTouchID: Bool = false,
                                                                    promptTouchID: Bool = false,
                                                                    showCancel: Bool = false,
                                                                    showSettingsGear: Bool = true) -> SDKAuthenticationViewController? {
        log(verbose: "Pushing/Displaying authentication username password view controller")
        log(verbose: "showWorkOffline: \(showWorkOffline)")
        log(verbose: "showToken: \(showToken)")
        log(verbose: "showTouchID: \(showTouchID)")
        log(verbose: "promptTouchID: \(promptTouchID)")
        log(verbose: "showCancel: \(showCancel)")
        log(verbose: "showSettingsGear: \(showSettingsGear)")

        guard let viewController = self.create(viewControllerType: SDKAuthenticationViewController.self) else {
            log(error:"Failed to generate the view controller of SDKAuthenticationViewController")
            return nil
        }

        viewController.resetValuesToStartStateOfController()
        viewController.displayButtonsCorrectlyAndSetFirstResponder()
        viewController.showTouchID = showTouchID
        viewController.promptTouchID = promptTouchID
        viewController.showCancel  = showCancel
        viewController.showWorkOffline   = showWorkOffline
        viewController.showTokenID      = showToken
        viewController.showSettingsGear = showSettingsGear
        viewController.authenticationDelegate   = delegate
        viewController.settingsDelegate         = delegate
        viewController.cancelDelegate           = delegate
        

        _ = self.sdkWindowManager.present(viewController: viewController,
                                            windowType: SDKWindowType.authentication,
                                            navigationStack: self.navigationController,
                                            animationType: .modal)

        return viewController
    }
    // Passcode Validation
    @discardableResult open func pushPasscodeValidation(delegate: PasscodeValidationViewControllerDelegate,
                                                        showTouchID: Bool,
                                                        promptTouchID: Bool) -> SDKPasscodeValidationViewController? {
        log(verbose: "Pushing/Displaying passcode validation view controller")
        log(verbose: "showTouchID: \(showTouchID)")
        log(verbose: "promptTouchID: \(promptTouchID)")

        guard let viewController = self.create(viewControllerType: SDKPasscodeValidationViewController.self) else {
            log(error:"Failed to generate view controller of SDKPasscodeValidationViewController")
            return nil
        }

        viewController.resetValuesToStartStateOfController()
        viewController.displayButtonsCorrectlyAndSetFirstResponder()
        viewController.passcodeValidationDelegate = delegate
        viewController.showTouchIDButton = showTouchID
        viewController.promptTouchID = promptTouchID

        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
        
        return viewController
    }

    // Create Passcode
    @discardableResult open func pushCreatePasscode(delegate: CreatePasscodeViewControllerDelegate,
                                                    restrictor: PasscodeComplianceProtocol,
                                                    showCancel: Bool = false,
                                                    showSSOOnePasscodeFooter: Bool = true) -> SDKCreatePasscodeViewController? {

        log(verbose:"Pushing/Displaying create passcode view controller")
        log(verbose:"showCancel: \(showCancel)")

        guard let viewController = self.create(viewControllerType: SDKCreatePasscodeViewController.self) else {
            log(error:"Failed to generate the view controller of SDKCreatePasscodeViewController")
            return nil
        }

        viewController.createPasscodeDelegate = delegate
        viewController.delegatePasscodeComplianceDetector = restrictor
        viewController.showCancel = showCancel
        viewController.showSSOPasscodeFooterLabel = showSSOOnePasscodeFooter

        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
        return viewController
    }

    // Change Passcode
    @discardableResult open func pushChangePasscode(delegate: ChangePasscodeViewControllerDelegate,
                                                    validator: PasscodeValidationProtocol,
                                                    restrictor: PasscodeComplianceProtocol,
                                                    showCancel: Bool,
                                                    showSSOOnePasscodeFooter: Bool = true) -> SDKChangePasscodeViewController? {
        log(verbose:"Pushing/Displaying change passcode view controller")
        log(verbose:"showCancel: \(showCancel)")

        guard let viewController = self.create(viewControllerType: SDKChangePasscodeViewController.self) else {
            log(error:"Failed to generate the view controller of SDKChangePasscodeViewController")
            return nil
        }

        viewController.changePasscodeDelegate = delegate
        viewController.showCancel             = showCancel
        viewController.delegatePasscodeValidator = validator
        viewController.delegatePasscodeComplianceDetector = restrictor
        viewController.showSSOPasscodeFooterLabel = showSSOOnePasscodeFooter

        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
        
        return viewController
    }
    open func pop() {
        if sdkWindowManager.pop(fromNavigation: navigationController) == false {
            sdkWindowManager.dismiss(SDKWindowType.authentication, animationType: .modal)
            navigationController = SDKNavigationController()
            navigationController.loadView()
            navigationController.navigationBar.isHidden = true
        }
    }
    open func dismiss(_ windowType: SDKWindowType, animationType: SDKAnimationType = .none) {
        guard self.sdkWindowManager.blockPresentationOfNewViewController == false else {
            return
        }
        sdkWindowManager.dismiss(windowType, animationType: animationType)
        if windowType == SDKWindowType.authentication {
            navigationController = SDKNavigationController()
            navigationController.loadView()
            navigationController.navigationBar.isHidden = true
        }
    }
    @discardableResult open func displayLoadingScreen() -> SDKLoadingScreenViewController? {

        guard let viewController = self.create(viewControllerType: SDKLoadingScreenViewController.self) else {
            log(error: "Failed to generate the view controller of SDKLoadingScreenViewController")
            return nil
        }
        log(verbose:"Displaying loading screen view controller")
        
        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
        return viewController
    }
    //MARK: Display/Dismiss view controllers in new window
    open func displayServerDetails(delegate: ServerDetailsViewControllerDelegate,
                                   previouslySavedServerURL: String?,
                                   previouslySavedServerGroup: String?,
                                   animation: SDKAnimationType = SDKAnimationType.none) {
        log(verbose:"Displaying server details view controller")
        log(verbose:"serverURL: \(String(describing: previouslySavedServerURL))")
        log(verbose:"serverGroup: \(String(describing: previouslySavedServerGroup))")

        guard let viewController = self.create(viewControllerType: SDKServerDetailsViewController.self) else {
            log(error:"Failed to generate the view controller of SDKServerDetailsViewController")
            return
        }

        viewController.serverDelegate = delegate
        viewController.serverURL = previouslySavedServerURL
        viewController.serverGroupID = previouslySavedServerGroup

        let serverDetailsNavigationalController = SDKNavigationController()
        serverDetailsNavigationalController.setToolbarHidden(true, animated: false)
        
        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
    }

    
    //MARK: Display/Dismiss view controllers in new window
    open func displayEmailAccount(delegate: EmailAccountViewControllerDelegate) {
        guard let viewController = self.create(viewControllerType: SDKEmailAccountViewController.self) else {
            log(error: "Failed to generate the view controller of SDKEmailAccountViewController")
            return
        }
        
        log(verbose: "Displaying email account view controller")
        
        viewController.emailAccountDelegate = delegate
        
        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
    }
    
    open func pushOnboardScreen(delegate: OnboardingViewControllerDelegate, emailAddress: String?) {
        log(verbose:"Displaying sign in view controller")

        guard let viewController = self.create(viewControllerType: SDKOnboardingViewController.self) else {
            log(error: "Failed to generate the view controller of SDKSignInViewController")
            return
        }

        viewController.onboardingDelegate   = delegate
        viewController.emailAddress         = emailAddress

        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: self.navigationController,
                                          animationType: .modal)
    }
    
    open func displayErrorScreen(delegate: FatalErrorViewControllerDelegate, errorCode: String?, allowRestart: Bool = false) {
        log(verbose: "Displaying fatal error view controller")
        log(debug:"Fatal error view controller error Code: \(String(describing: errorCode))")
        
        guard let viewController = SDKViewControllerGenerator<FatalErrorViewController>(storyboard: storyboard).viewController else { return }
        viewController.fatalErrorDelegate = delegate
        viewController.errorCodeText = errorCode
        viewController.allowRestart = allowRestart
        
        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.blocker,
                                          navigationStack: nil,
                                          animationType: .none)
    }
    /*!
     * @brief Push SAML view controller with a web view onto the authentication window so that the user may authenticate through the web. If the authentication window is not present, then it will slide up from the bottom of the app.
     @param urlForSAML The url in which to pass to the view web view
     @param: delegate implement this method so that you can use some form to get the HMAC from the token
     */
    open func pushSAML(url urlForSAMLAuthenticationEndpoint: URL,
                       callbackScheme: String,
                       allowCancel: Bool,
                       samlDelegate: SAMLTokenDelegate) -> Bool {
        log(verbose:"Pushing/Displaying SAML view controller")
        log(verbose: "urlForSAML: \(urlForSAMLAuthenticationEndpoint)")

        guard let viewController = self.create(viewControllerType: SAMLViewController.self) else {
            log(error:"Failed to generate the view controller of SDKSignInViewController")
            return false
        }

        viewController.callbackScheme = callbackScheme
        viewController.allowCancel = allowCancel
        viewController.url = urlForSAMLAuthenticationEndpoint
        viewController.samlDelegate = samlDelegate
        
        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.authentication,
                                          navigationStack: navigationController,
                                          animationType: .modal)

        return true
    }

    /**
     The default animation is Modal and cannot be changed because this function creates another window and puts it on top of all the other windows
     */
    open func displayBlocker(message: String,
                             animation: SDKAnimationType? = nil) {
        log(verbose: "Displaying blocker view controller")
        log(verbose: "displayBlocker: \(message)")

        guard let viewController = self.create(viewControllerType: SDKBlockerViewController.self) else {
            log(error: "Failed to generate the view controller of SDKBlockerViewController")
            return
        }

        viewController.blockerMessage = message
        viewController.dismissKeyboard()

        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.blocker,
                                          navigationStack: nil,
                                          animationType: .none)
    }

    open func displayJailbroken() -> JailbrokenViewController? {
        log(verbose: "Displaying jailbroken view controller")
        guard let viewController = self.create(viewControllerType: SDKJailbrokenViewController.self) else {
            log(error: "Failed to generate the view controller of SDKJailbrokenViewController")
            return nil
        }
        
        _ = self.sdkWindowManager.present(viewController: viewController,
                                          windowType: SDKWindowType.blocker,
                                          animationType: .none)
        return viewController
    }
    
    open func displayBackgroundBlocker() -> () {
        log(debug: "Started Displaying Blocker View")
        
        let windowManager: SDKWindowManager = SDKWindowManager.shared
        
        var topWindow: UIWindow? = nil
        if windowManager.isWindowCurrentlyDisplayed(.background) {
            topWindow = windowManager.getWindow(.background)
        } else if windowManager.isWindowCurrentlyDisplayed(.blocker) {
            topWindow = windowManager.getWindow(.blocker)
        } else if windowManager.isWindowCurrentlyDisplayed(.authentication) {
            topWindow = windowManager.getWindow(.authentication)
        } else {
            topWindow = windowManager.applicationWindow
        }
        guard let window = topWindow else {
            log(error: "!Error! Failed to find Top Window, could not display blocker view!")
            return
        }
        
        // ISDK-169776 (Reopened 7/31/2017) - Fix blocker not showing up in app switcher for iPhone Plus model
        // Dismisses keyboard properly to ensure blocker appears for cases when a textfield is active
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        
        SDKPresenter.backgroundBlocker.frame = window.frame
        window.addSubview(SDKPresenter.backgroundBlocker)
        window.bringSubview(toFront: SDKPresenter.backgroundBlocker)
        self.disable()
        log(debug: "Finished Displaying Blocker View")
    }

    open func dismissBackgroundBlocker() -> () {
        self.enable()
        log(debug: "Started Dismissing Blocker View")
        SDKPresenter.backgroundBlocker.removeFromSuperview()
        log(debug: "Finished Dismissing Blocker View")
    }
    
    static func createBlockerView() -> UIView {
        let subviewArray = Bundle(for: SDKPresenter.self).loadNibNamed("BackgroundBlockerView", owner: nil, options: nil)
        
        guard let blockerView: UIView = subviewArray?.first as? UIView else {
            log(error: "Error!!: Failed to create static blocker view! Creating Plain UI Blocking view with no logo's")
            let blankView: UIView = UIView(frame: SDKWindowManager.shared.applicationWindow.frame)
            blankView.backgroundColor = UIColor.blue
            return blankView
        }
        return blockerView
    }
}
