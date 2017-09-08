//
//  SDKUITextField.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit
import CoreGraphics

class AWColor {
    static let gray: UIColor = UIColor(red: 246/255, green: 247/255, blue: 248/255, alpha: 1)
    static let unfocusedColor: UIColor = UIColor(red: 157.0/255, green: 162.0/255, blue: 168.0/255, alpha: 1.0)
    static let focusedColor: UIColor = UIColor(red: 60.0/255, green: 70.0/255, blue: 83.0/255, alpha: 1.0)
    static let disabledAlphaValue: CGFloat = 0.25
    static let enabledAlphaValue: CGFloat = 1.0
}

public class SDKUITextField: UITextField {
    var showHideButton: UIButton? = nil
    var showHideButtonExists: Bool = false
    var underlineView : UIView?
    let underlineViewHeight = CGFloat(1.0)
    var preferredFont : UIFont? = nil

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        createUnderlineView()
        underlinedUnfocused()
        disableInputAssistantView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        underlineView!.frame = CGRect(x: 0, y: self.frame.size.height - underlineViewHeight, width: self.frame.size.width, height: underlineViewHeight)
    }
    
    func disableInputAssistantView() {
        self.inputAssistantItem.leadingBarButtonGroups = []
        self.inputAssistantItem.trailingBarButtonGroups = []
    }

    func createUnderlineView() {
        underlineView = UIView(frame: CGRect(x: 0, y: self.frame.size.height - underlineViewHeight, width: self.frame.size.width, height: underlineViewHeight))
        self.addSubview(underlineView!)
    }
    
    required override public init(frame: CGRect) {
        super.init(frame: frame)
        createUnderlineView()
        underlinedUnfocused()
    }
    
    override public func becomeFirstResponder() -> Bool {
        if SDKWindowManager.shared.isWindowCurrentlyDisplayed(.blocker) {
            return false
        }
        super.becomeFirstResponder()
        self.textColor = AWColor.focusedColor
        underlinedFocused()
        return true
    }
    
    override public func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
        self.textColor = AWColor.unfocusedColor
        underlinedUnfocused()
        return true
    }
    
    ///disable the text field and change color accordingly
    func disable() {
        self.isEnabled = false
        self.alpha = AWColor.disabledAlphaValue
        if showHideButtonExists {
            showHideButton?.isEnabled = false
            self.textColor = AWColor.unfocusedColor
            underlinedUnfocused()
            showHideButton?.alpha = AWColor.disabledAlphaValue
        }
    }
    
    ///enable the text field and change color accordingly
    func enable() {
        self.isEnabled = true
        self.alpha = AWColor.enabledAlphaValue
        if showHideButtonExists {
            showHideButton?.isEnabled = true
            showHideButton?.alpha = AWColor.enabledAlphaValue
        }
    }
    
    func underlinedFocused(){
        underlineView!.backgroundColor = AWColor.focusedColor
    }
    
    func underlinedUnfocused(){
        underlineView!.backgroundColor = AWColor.unfocusedColor
    }
}

public extension SDKUITextField
{
    public override func awakeFromNib() {
        super.awakeFromNib()
        preferredFont = self.font
    }
    
    public func updateSecureEntry(isSecure secure: Bool) {
        isSecureTextEntry = secure
        font = nil;
        font = preferredFont
        _ = becomeFirstResponder()
    }
    

}

//MARK:- Font support
fileprivate struct AWFontSize {
    static let Compact : CGFloat = 17
    static let Regular : CGFloat = 20
}

public extension SDKUITextField {
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if(self.traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass || self.traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass) {
            var size : CGFloat = AWFontSize.Compact
            if(self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.regular && self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClass.regular){
                size = AWFontSize.Regular
            }
            self.font = UIFont.systemFont(ofSize: size, weight: UIFontWeightRegular)
            self.preferredFont = self.font
        }
    }

}

