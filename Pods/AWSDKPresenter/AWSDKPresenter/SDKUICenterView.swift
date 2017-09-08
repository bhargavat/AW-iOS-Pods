//
//  SDKUICenterView.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit


fileprivate struct SDKUICenterViewTopYRatio {
    static let iPadPortrait : CGFloat = 0.175
    static let iPadLandscape : CGFloat = 0.175
    static let iPadLandscapeWithKeyboard : CGFloat = 0.07
    static let iPhonePortrait : CGFloat = 0.175
    static let iPhonePortraitWithKeyboard : CGFloat = 0.0825
}

fileprivate class SDKUICenterViewAnimator {
    
    private(set) var isKeyboardVisible : Bool = false
    private(set) weak var constraintToAdjust: NSLayoutConstraint?
    private(set) weak var viewWithConstraint: UIView?
    init(constraint: NSLayoutConstraint?, callingView: UIView?) {
        constraintToAdjust = constraint
        viewWithConstraint = callingView
        registerForShowAndHideKeyboardNotifications()
    }
    
    private func registerForShowAndHideKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(willShowKeyboard(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willHideKeyboard(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK:- Show/Hide Keyboard Notifications
    @objc private func willShowKeyboard(_ notificationObj: Notification) {
        isKeyboardVisible = true
        animate()
    }
    
    @objc private func willHideKeyboard(_ notificationObj: Notification) {
        isKeyboardVisible = false
        animate()
        
    }
    
    //MARK: Helper Methods
    private func calculateCenterViewTopYValue(orientation : UIInterfaceOrientation) -> CGFloat {
        var topYValue : CGFloat = 0
        if UIInterfaceOrientationIsPortrait(orientation) {
            if (shouldAnimateIniPhone()) {
                topYValue = (isKeyboardVisible ? SDKUICenterViewTopYRatio.iPhonePortraitWithKeyboard : SDKUICenterViewTopYRatio.iPhonePortrait) * (self.viewWithConstraint?.bounds.size.height)!
            }
            else {
                topYValue = SDKUICenterViewTopYRatio.iPadPortrait * (self.viewWithConstraint?.bounds.size.height)!
            }
        }
        else if UIInterfaceOrientationIsLandscape(orientation) {
            topYValue = (isKeyboardVisible ? SDKUICenterViewTopYRatio.iPadLandscapeWithKeyboard : SDKUICenterViewTopYRatio.iPadLandscape) * (self.viewWithConstraint?.bounds.size.height)!
        }
        return topYValue
    }
    
    func animate() {
        let centerViewTopY = calculateCenterViewTopYValue(orientation: UIApplication.shared.statusBarOrientation)
        if(centerViewTopY != self.constraintToAdjust?.constant){
            self.constraintToAdjust?.constant = centerViewTopY
            viewWithConstraint?.layoutIfNeeded()
        }
    }
    
    private func shouldAnimateIniPhone() -> Bool {
        return (self.viewWithConstraint?.bounds.size.height)! <= CGFloat(568)
    }
    
}

open class SDKUICenterView: UIView {
    
    @IBOutlet weak var centerViewTopConstraint: NSLayoutConstraint?
    fileprivate var centerViewAnimator : SDKUICenterViewAnimator?
    override open func awakeFromNib() {
        super.awakeFromNib()
        centerViewAnimator = SDKUICenterViewAnimator(constraint: centerViewTopConstraint, callingView: self.superview)
    }
    override open func layoutSubviews() {
        super.layoutSubviews()
        centerViewAnimator?.animate()
    }
    
    override open func updateConstraints() {
        centerViewAnimator?.animate()
        super.updateConstraints()
    }
    
}
