//
//  ScrollViewHandler.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CoreGraphics
import UIKit

internal class ScrollViewHandler {
    internal static let sharedInstance: ScrollViewHandler = ScrollViewHandler()
    internal var keyboardRect: CGRect?
    
    internal var scrollView: UIScrollView?
    internal var viewToScrollTo: UIView?
    
    internal func slideToShowView(_ keyboard: CGRect?, extraPadding: CGFloat = 15) -> Bool {
        
        let internalScrollVeiw = ScrollViewHandler.sharedInstance.scrollView
        let internalViewToScrollTo = ScrollViewHandler.sharedInstance.viewToScrollTo
        
        if (keyboard == nil || internalScrollVeiw == nil || internalViewToScrollTo == nil) {
            return false
        }
        
        let viewHeight = internalViewToScrollTo!.frame.height
        let yPosition = internalScrollVeiw!.convert(CGPoint.zero, from: viewToScrollTo).y
        
        let bottomPositionOfViewInPoints = viewHeight + yPosition
        let highestPointOfKeyboard = (scrollView?.frame.size.height)! - (keyboard?.height)!
        
        if (Int(bottomPositionOfViewInPoints) < Int(highestPointOfKeyboard)) {
            return false
        }
        scrollView?.setContentOffset(CGPoint(x: 0,  y: bottomPositionOfViewInPoints - highestPointOfKeyboard + extraPadding), animated: true)
        return true
    }
    
    internal func resetScrollViewPosition() {
        scrollView?.setContentOffset(CGPoint(x: 0,  y: 0), animated: true)
    }
}
