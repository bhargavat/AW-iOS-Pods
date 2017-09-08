//
//  Protocols.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import Foundation

//MARK: Protocol used in multiple View Controllers
// These protocols are used by multiple view controllers
public protocol ViewControllerDisplaySettingsDelegate: class {
    func showServerDetails()
}

public enum PasscodeValidationResult {
    case ok                       // passcode is valid
    case wrongPasscode           // wrong passcode
    case maxFailedAttemptsMade // the max number of failed attempts allowed
}

public enum TouchIDResult {
    case successfullyAuthenticated
    case userCancelled
    case unavailable
}

public protocol PasscodeComplianceResult {
    var compliant: Bool { get }
    var complianceMessage: String  { get }
}

extension PasscodeValidationResult: Error, CustomErrorConvertible {
    public func userInfo() -> Dictionary<String, String>? {
        switch self {
        case .ok:
            return [NSLocalizedDescriptionKey: "Passcode successfully entered"]
        case .wrongPasscode:
            return [NSLocalizedDescriptionKey: "Passcode attempted to use was wrong"]
        case .maxFailedAttemptsMade:
            return [NSLocalizedDescriptionKey: "Passcode entered has reached max failed attempts"]
        }
    }
    public func errorDomain() -> String {
        return "com.air-watch.sdkpresenter"
    }
    public func errorCode() -> Int {
        return _code
    }
}

// Protocol method validatePasscode checks whether the input passcode is equal
// to passcode already stored by implementer
public protocol PasscodeValidationProtocol: class {
    // analagous to checkPasscodeValidity in Obj-C SDK
    func validatePasscode(_ passcode: String) -> PasscodeValidationResult
}

// Used to enforce restrictions/policies on the passcode
public protocol PasscodeComplianceProtocol: class {
    // Returns whether the passcode follows restrictions
    // analagous to checkCompliance in Obj-C SDK
    // Should get called before createUserPasscode() or changePasscode(:)
    func passcodeCompliesWithRestrictions(_ passcode: String?) -> PasscodeComplianceResult

    // Gets passcode restriction
    // Analogous to [passcodeHandler passcodePolicyRulesText] in Obj-C SDK
    func getPasscodeRestrictions() -> String
}

public protocol ViewControllerDisplayCancellationDelegate: class {
    func cancelViewController()
}


//MARK: Protocols specific to view controller
// These protocols are specific to a view controller
public protocol AuthenticationViewControllerDelegate: class, ViewControllerDisplayCancellationDelegate, ViewControllerDisplaySettingsDelegate {
    func login(username: String, password: String, rememberUser: Bool, workOffline: Bool, completionHandler: @escaping ((Bool)->Void))
    func unlockWithTouchID(completionHandler: @escaping (_ result: TouchIDResult)->Void)
    func login(authenticationToken: String, completionHandler: @escaping ((Bool)->Void))
    func rememberedUsernameToAutofill() -> String?
}

public protocol CreatePasscodeViewControllerDelegate: class {
    // Called by the view controller to tell the delegate to create the passcode
    func createPasscode(new passcode: String?,
                        confirm confirmPasscode: String?,
                        completionHandler: @escaping (_ success: Bool, _ error: NSError?) -> Void)
    // Tells the delegate that the view controller is finished
    // if successful, `success` would be `true`, `errorOpt` would be `nil`
    // if not,`success` would be `true`, `errorOpt` would be some NSError
    func createPasscodeViewControllerFinished(success: Bool, error errorOpt: NSError?)
}

public protocol ChangePasscodeViewControllerDelegate: class {

    // Called by the view controller to tell the delegate to change the passcode
    func changePasscode(new newPasscode: String?,
                        old oldPasscode: String?,
                        completionHandler:(_ success: Bool, _ error: NSError?) -> Void)

    // Tells the delegate that the view controller is finished
    // if successful, `success` would be `true`, `errorOpt` would be `nil`
    // if not,`success` would be `true`, `errorOpt` would be some NSError
    func changePasscodeViewControllerFinished(success: Bool, error errorOpt: NSError?)

}

public protocol PasscodeValidationViewControllerDelegate: class {
    func passcodeValidator(_ passcode: String) -> PasscodeValidationResult
    func unlockWithTouchID(completionHandler: @escaping (_ result: TouchIDResult)->Void)
    func showForgotPasscodeScreen()
}

public protocol ServerDetailsViewControllerDelegate: class {
    func validateServerDetails(_ url: String?,
                               organizationGroup: String?,
                               completionHandler: @escaping ((Bool)->Void))
    func userDidDismissServerDetailsViewController()
}

public protocol EmailAccountViewControllerDelegate: class {
    func attemptAutodiscovery(email: String?, completionHandler: @escaping ((Bool)->Void))
    func endUserLicenseAgreementRequested() -> String // Don't know what form the EULA will be in if it will be a webpage or what
    func manualSetupWithServerDetails()
    func saveEmail(email: String)
}

public protocol OnboardingViewControllerDelegate: class {
    func onboardUser(onboardedSuccessfully: @escaping (Bool) -> Void)
}

public protocol TermsAndConditionsViewControllerDelegate: class {
    func termsAcceptance(accepted: Bool)
}

public protocol FatalErrorViewControllerDelegate: class {
    func restart()
}
