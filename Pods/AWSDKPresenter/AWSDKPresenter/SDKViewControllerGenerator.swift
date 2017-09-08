//
//  SDKViewControllerGenerator
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

final public class SDKViewControllerGenerator<A> {
    let storyboard : UIStoryboard
    
    init(storyboard: UIStoryboard?) {
        let sdkPresenterframeworkBundle = Bundle(for: SDKPresenter.self)
        self.storyboard = storyboard ?? UIStoryboard(name: "AWStoryboard", bundle: sdkPresenterframeworkBundle)
        log(verbose: "Storyboard: \(self.storyboard)")
    }
}

extension SDKViewControllerGenerator {
    var identifier : String? {
        switch A.self {
        case _ where A.self == SDKAuthenticationViewController.self:
            return "AuthenticationViewController"
        case _ where A.self == SDKBlockerViewController.self:
            return "BlockerViewController"
        case _ where A.self == SDKChangePasscodeViewController.self:
            return "ChangePasscodeViewController"
        case _ where A.self == SDKCreatePasscodeViewController.self:
            return "CreatePasscodeViewController"
        case _ where A.self == SDKEmailAccountViewController.self:
            return "EmailAccountViewController"
        case _ where A.self == SDKPasscodeValidationViewController.self:
            return "PasscodeValidationViewController"
        case _ where A.self == SDKServerDetailsViewController.self:
            return "ServerDetailsViewController"
        case _ where A.self == SDKOnboardingViewController.self:
            return "OnboardingViewController"
        case _ where A.self == SAMLViewController.self:
            return "SAMLViewController"
        case _ where A.self == SDKLoadingScreenViewController.self:
            return "LoadingScreenViewController"
        case _ where A.self == SDKJailbrokenViewController.self:
            return "JailbrokenViewController"
        case _ where A.self == FatalErrorViewController.self:
            return "FatalErrorViewController"
        default:
            return nil
        }
    }
    
    var viewController : A? {
        return create()
    }
}

extension SDKViewControllerGenerator {
    fileprivate func create<A>() -> A? {
        guard let vcIdentifier = identifier else {
            log(error: "Trying to load ViewController \(A.self), but the Identifier is invalid")
            return nil
        }
        
        guard let viewController = storyboard.instantiateViewController(withIdentifier: vcIdentifier) as? A else {
            log(error: "Loading ViewController \(A.self) with Identifier \(vcIdentifier) failed")
            return nil
        }
        
        log(debug: "ViewController identifier is \(vcIdentifier)")
        log(debug: "ViewController is \(viewController)")
        return viewController
    }
}
