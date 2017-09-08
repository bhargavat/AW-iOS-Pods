//
//  AlertPresenter.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit
import Foundation
import AWLocalization

public protocol PresentationQueue {
    func perform(_ block:@escaping  (Void)-> Void)
}

public protocol WindowPresenter {
    var window: UIWindow? { get }
    var queue: PresentationQueue { get }
    func present(_ controller: UIViewController)
}

extension DispatchQueue: PresentationQueue {
    public func perform(_ block: @escaping (Void)-> Void) {
        self.async {
            block()
        }
    }
}

public extension WindowPresenter {
    func present(_ controller: UIViewController) {
        if let viewController = window?.rootViewController {
            queue.perform {
                viewController.present(controller, animated: true, completion: nil)
            }
        }
    }
}

public protocol AlertInformationProvider {
    var title: String? { get }
    var message: String? { get }
    var actions: [UIAlertAction]? { get }
}

public protocol  WindowAlertPresenter {
    var presenter: WindowPresenter { get }
    func show() -> UIAlertController
}

public struct MainWindowPresenter: WindowPresenter {
    public let queue: PresentationQueue = DispatchQueue.main
    public let window = UIApplication.shared.keyWindow
}

@objc
public class KeyWindowAlert: NSObject, AlertInformationProvider, WindowAlertPresenter {
    public let title: String?
    public let message: String?
    public var actions: [UIAlertAction]?
    public let presenter: WindowPresenter = MainWindowPresenter()

    @objc
    public init(title: String?, message: String?, actions: [UIAlertAction]? = nil) {
        self.title = title
        self.message = message
        self.actions = actions
    }

    public func show() -> UIAlertController {
        AWLogVerbose("KeyWindowAlert is presenting with title \"\(title ?? "Title:")\" and message \"\(message ?? "")\"")
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        let actions = self.actions ?? [UIAlertAction(title: AWSDKLocalization.getLocalizationString("Ok"), style: UIAlertActionStyle.cancel, handler: nil)]
        actions.forEach { (action) in
            alertController.addAction(action)
        }
        presenter.present(alertController)
        return alertController
    }

}
