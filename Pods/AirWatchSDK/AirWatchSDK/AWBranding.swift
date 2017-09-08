//
//  AWBranding.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWPresentation

@objc
public class AWBranding: NSObject {
    public private(set) static var sharedBranding = AWBranding()
    private let brandingManager: AWBrandingManager
    
    private override init () {
        self.brandingManager = AWBrandingManager.sharedInstance
    }
    
    // MARK: Text
    /**
     @return Retrieve from the payload the organization name set in console. nil will be returned if nothing was present
     */
    public func organizationName() -> String? {
        return AWController.sharedInstance.sdkProfile()?.brandingPayload?.organizationName
    }
    
    // MARK: Colors
    public func toolbarColor() -> UIColor? {
        return self.brandingManager.toolbarColor
    }
    public func toolbarTextColor() -> UIColor? {
        return self.brandingManager.toolbarTextColor
    }
    public func primaryColor() -> UIColor? {
        return self.brandingManager.primaryColor
    }
    public func secondaryColor() -> UIColor? {
        return self.brandingManager.secondaryColor
    }
    public func primaryTextColor() -> UIColor? {
        return self.brandingManager.primaryTextColor
    }
    public func secondaryTextColor() -> UIColor? {
        return self.brandingManager.secondaryTextColor
    }
    
    // MARK: Images
    /**
     @brief Attempt to retrieve the background image set by console or plist entry, or nil if not set.
     @description If console branding is enabled then the downloaded image from console will be returned if it was set and downloaded. If the file could not be downloaded or was not set, then attempt to retrieve an image from the plist entry set in AWSDKDefaultSettings. If the image does not exist or was not set, nil is returned. The appropriate image will be returned based on device currently being used.
     */
    public func primaryImage() -> UIImage? {
        return self.brandingManager.imageBackground
    }
    
    /**
     @brief Attempt to retrieve the company logo image set by console or plist entry or the default VMWare logo.
     @description If console branding is enabled then the downloaded image from console will be returned if it was set and downloaded. If the file could not be downloaded or was not set, then attempt to retrieve an image from the plist entry set in AWSDKDefaultSettings. If the image does not exist or was not set, nil is returned. The appropriate image will be returned based on device currently being used.
     */
    public func secondaryImage() -> UIImage? {
        return self.brandingManager.imageAppLogo
    }
}
