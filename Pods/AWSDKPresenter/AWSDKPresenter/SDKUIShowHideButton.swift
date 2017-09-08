//
//  SDKUIShowHideButton.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit

public enum SDKUIShowHideButtonState {
    case ShowPassword
    case HidePassword
    case HideButton
}

open class SDKUIShowHideButton: UIButton {
    
    required public init?(coder aDecoder: NSCoder) {
        self.buttonState = .HideButton
        super.init(coder: aDecoder)
    }
    
    public var buttonState : SDKUIShowHideButtonState {
        didSet {
            updateView()
        }
    }
    
    override open func backgroundRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: 26, y: 15, width: 18, height: 14)
    }
    
    func updateView() {
        var icon : UIImage? = nil
        let bundle = Bundle(for: object_getClass(SDKUITextField.self))
        switch buttonState {
        case .ShowPassword:
            self.isHidden = false
            icon = UIImage(named: "icon_show", in: bundle, compatibleWith: nil)
        case .HidePassword:
            self.isHidden = false
            icon = UIImage(named: "icon_hide", in: bundle, compatibleWith: nil)
        case .HideButton:
            self.isHidden = true
        }
        self.setBackgroundImage(icon, for: UIControlState.normal)
    }
}
