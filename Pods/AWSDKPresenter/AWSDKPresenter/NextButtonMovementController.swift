//
//  NextButtonMovementController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

private let DefaultNextButtonConstraintFromBottomEdge: CGFloat = 216.0

class NextButtonMovementController {
    
    var constraintToAdjust: NSLayoutConstraint
    var viewWithConstraint: UIView
    
    init(constraint: NSLayoutConstraint, callingView: UIView) {
        constraintToAdjust = constraint
        viewWithConstraint = callingView
        NotificationCenter.default.addObserver(self, selector: #selector(moveNextButtonUpUsingConstraint(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveNextButtonDownUsingConstraint(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    
    func changeNextButtonConstraint(value: CGFloat) {
        self.constraintToAdjust.constant = value
    }
    
    @objc private func moveNextButtonUpUsingConstraint(_ notificationObj: Notification) {
        var moveConstraintForNextButton: CGFloat = DefaultNextButtonConstraintFromBottomEdge
        let keyboardInfo = notificationObj.userInfo
        if let keyboardFrame: CGRect = (keyboardInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight: CGFloat = keyboardFrame.height
            moveConstraintForNextButton =  keyboardHeight
        }
        
        self.changeNextButtonConstraint(value: moveConstraintForNextButton)
    }
    
    @objc private func moveNextButtonDownUsingConstraint(_ notificationObj: Notification) {
        self.changeNextButtonConstraint(value: 0)
    }
}
