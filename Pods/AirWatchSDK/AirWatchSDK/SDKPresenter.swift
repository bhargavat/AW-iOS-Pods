//
//  SDKPresenter.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWPresentation
import AWLocalization
import AWHelpers

public struct TouchIDOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let allowTouchID               = TouchIDOptions(rawValue: 1 << 0)
    public static let promptTouchID              = TouchIDOptions(rawValue: 1 << 1)
    
    public static let none: TouchIDOptions = []
    public static let allowAndPrompt: TouchIDOptions = [.allowTouchID, .promptTouchID]
}

public struct AuthenticationOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let allowTokenInput            = AuthenticationOptions(rawValue: 1 << 0)
    public static let allowCancel                = AuthenticationOptions(rawValue: 1 << 1)
    public static let allowSettingsUpdate        = AuthenticationOptions(rawValue: 1 << 2)
    public static let allowRememberUsername      = AuthenticationOptions(rawValue: 1 << 3)
    public static let allowWorkingOffline        = AuthenticationOptions(rawValue: 1 << 4)

    public static let identitySetupOptions: AuthenticationOptions = [.allowTokenInput, .allowSettingsUpdate]

    public static let passcodeResetOptions: AuthenticationOptions = [.allowTokenInput, .allowCancel, allowSettingsUpdate]

    public static let unlockOptions: AuthenticationOptions = [.allowRememberUsername]
    
    public static let updateUserCredentialOptions : AuthenticationOptions = [.allowCancel]
}

public protocol SAMLConfigurtion {
    var url: URL { get }
    var callbackScheme: String { get }
}

public struct SAMLAuthenticationOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let allowCancel                        = SAMLAuthenticationOptions(rawValue: 1 << 2)
    public static let none: SAMLAuthenticationOptions = []
    public static let passcodeResetOptions: SAMLAuthenticationOptions = [.allowCancel]
}

internal protocol SDKQueuePresenter {
    var presenter: SDKPresenter { get }
    var presentationQueue: PresentationQueue { get }


    func enable() -> ()
    func disable() -> ()
    func reset() -> ()

    func presentAuthentication(options: AuthenticationOptions, touchIDOptions: TouchIDOptions, delegate: AuthenticationViewControllerDelegate)
    func performSAMLAuthentication(configurtion: SAMLConfigurtion, options: SAMLAuthenticationOptions, delegate: SAMLTokenDelegate)


    func pushPasscodeValidation(delegate: PasscodeValidationViewControllerDelegate,
                                touchIDOptions: TouchIDOptions)
    
    func pushCreatePasscode(delegate: CreatePasscodeViewControllerDelegate,
                            restrictor: PasscodeComplianceProtocol,
                            showCancel: Bool,
                            showSSOLabel: Bool)

    func pushChangePasscode(delegate: ChangePasscodeViewControllerDelegate,
                            validator: PasscodeValidationProtocol,
                            restrictor: PasscodeComplianceProtocol,
                            showCancel: Bool,
                            showSSOLabel: Bool)

    func pop()
    
    func displayServerDetails(delegate: ServerDetailsViewControllerDelegate, serverURL: String?, serverGroup: String?)
    func displayEmailAccountScreen(delegate: EmailAccountViewControllerDelegate)
    func displayLoadingScreen()
    func displayBlocker(message: String)
    func displayJailbroken()
    func displayBackgroundBlocker()
    func dismissBackgroundBlocker()
    
    func dismiss(_ windowType: SDKWindowType)
    func dismissNonBlockingViewControllers()
    func dismissAllViewControllers()
}

extension SDKQueuePresenter {

    func enable() -> () {
        self.presenter.enable()
    }
    
    func disable() -> () {
        self.presenter.disable()
    }

    func reset() -> () {
        self.presenter.reset()
    }
    
    func presentAuthentication(options: AuthenticationOptions, touchIDOptions: TouchIDOptions, delegate: AuthenticationViewControllerDelegate){
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.pushAuthenticationUsernamePassword(delegate: delegate,
                                                                showWorkOffline: options.contains(.allowWorkingOffline),
                                                                showToken: options.contains(.allowTokenInput),
                                                                showTouchID: touchIDOptions.contains(.allowTouchID),
                                                                promptTouchID: touchIDOptions.contains(.promptTouchID),
                                                                showCancel: options.contains(.allowCancel),
                                                                showSettingsGear: options.contains(.allowSettingsUpdate))
        }
    }
    func pushPasscodeValidation(delegate: PasscodeValidationViewControllerDelegate, touchIDOptions: TouchIDOptions) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.pushPasscodeValidation(delegate: delegate, showTouchID: touchIDOptions.contains(.allowTouchID), promptTouchID: touchIDOptions.contains(.promptTouchID))
        }
        
    }

    func pushCreatePasscode(delegate: CreatePasscodeViewControllerDelegate, restrictor: PasscodeComplianceProtocol, showCancel: Bool, showSSOLabel: Bool = true) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.pushCreatePasscode(delegate: delegate, restrictor: restrictor, showSSOOnePasscodeFooter: showSSOLabel)
        }
    }
    
    func pushChangePasscode(delegate: ChangePasscodeViewControllerDelegate, validator: PasscodeValidationProtocol, restrictor: PasscodeComplianceProtocol, showCancel: Bool, showSSOLabel: Bool = true) {
        
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.pushChangePasscode(delegate: delegate, validator: validator, restrictor: restrictor, showCancel: showCancel, showSSOOnePasscodeFooter: showSSOLabel)
        }
    }

    func performSAMLAuthentication(configurtion: SAMLConfigurtion, options: SAMLAuthenticationOptions, delegate: SAMLTokenDelegate) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.pushSAML(url: configurtion.url,
                                      callbackScheme: configurtion.callbackScheme,
                                      allowCancel: options.contains(.allowCancel),
                                      samlDelegate: delegate)
        }

    }

    func pop() {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.pop()
        }
    }
    
    func displayServerDetails(delegate: ServerDetailsViewControllerDelegate, serverURL: String?, serverGroup: String?) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.displayServerDetails(delegate: delegate, previouslySavedServerURL: serverURL, previouslySavedServerGroup: serverGroup, animation: SDKAnimationType.modal)
        }
    }
    
    func displayEmailAccountScreen(delegate: EmailAccountViewControllerDelegate) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.displayEmailAccount(delegate: delegate)
        }
    }
    
    func displaySecondAppSignInScreen(delegate: OnboardingViewControllerDelegate, emailAddress: String?) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.pushOnboardScreen(delegate: delegate, emailAddress: emailAddress)
        }
    }
    
    func displayLoadingScreen() {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.displayLoadingScreen()
        }
    }
    
    
    func displayBlocker(message: String) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.displayBlocker(message: message, animation: SDKAnimationType.modal)
        }
    }
    
    func displayJailbroken() {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.displayJailbroken()
        }
    }
    
    func displayBackgroundBlocker() {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.displayBackgroundBlocker()
        }
    }
    
    func displayFatalErrorBlocker(delegate: FatalErrorViewControllerDelegate, errorCode: String?, allowRestart: Bool = false) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.displayErrorScreen(delegate: delegate,
                                                errorCode: errorCode,
                                                allowRestart: allowRestart)
        }
    }
    
    func dismissBackgroundBlocker() {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            _ = vcPresenter?.dismissBackgroundBlocker()
        }
    }
    
    func dismiss(_ windowType: SDKWindowType) {
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.dismiss(windowType)
        }
    }
    
    func dismissNonBlockingViewControllers() {
        guard presenter.isPresenterVisible  else { return }
        
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.dismiss(SDKWindowType.authentication, animationType: .modal)
        }
    }
    
    func dismissAllViewControllers() {
        guard presenter.isPresenterVisible  else { return }
        
        let vcPresenter = presenter
        presentationQueue.perform { [weak vcPresenter] in
            vcPresenter?.dismiss(SDKWindowType.authentication, animationType: .modal)
            vcPresenter?.dismiss(SDKWindowType.blocker, animationType: .modal)
        }
    }
}

internal struct MainQueueSDKPresenter: SDKQueuePresenter {
    let presenter = SDKPresenter()
    let presentationQueue: PresentationQueue = DispatchQueue.main
}
