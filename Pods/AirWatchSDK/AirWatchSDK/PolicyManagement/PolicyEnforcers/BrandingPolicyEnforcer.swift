//
//  BrandingPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import Foundation
import AWServices
import AWPresentation
import AWHelpers

class BrandingPolicyEnforcer: PolicyEnforcementOperation {

    override var payloadType: String { return BrandingPayload.type }

    var brandingPayload: BrandingPayload? {
        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {

        var brandingManager = AWBrandingManager.sharedInstance

        guard let payload = self.brandingPayload, payload.enableBranding == true else {
            brandingManager.isConsoleBrandingEnabled = false
            self.enforcementComplete()
            return
        }

        brandingManager.isConsoleBrandingEnabled = true

        let aspectRatio = UIDevice.current.aspectRatio()
        var urlForBackgroundImage: URL?
        var urlForCompanyLogo: URL?

        if (aspectRatio == AspectRatio.device_3_2) {
            urlForBackgroundImage = payload.iPhone2xBackgroundImageURL
            urlForCompanyLogo = payload.iPhoneCompanyLogoURL
        } else if (UIScreen.main.scale == 1 && aspectRatio == AspectRatio.device_4_3) {
            urlForBackgroundImage = payload.iPadBackgroundImageURL
            urlForCompanyLogo = payload.iPadCompanyLogoURL
        } else if (UIScreen.main.scale == 2 && aspectRatio == AspectRatio.device_4_3) {
            urlForBackgroundImage = payload.iPad2xBackgroundImageURL
            urlForCompanyLogo = payload.iPad2xCompanyLogoURL
        }
        // We are currently not handling the case where an iPad is rotated because Console does not support it either
        else if (UIScreen.main.scale == 1 && aspectRatio == AspectRatio.device_16_9) {
            urlForBackgroundImage = payload.iPhoneBackgroundImageURL
            urlForCompanyLogo = payload.iPhoneCompanyLogoURL
        } else if ((UIScreen.main.scale == 2 || UIScreen.main.scale == 3) && aspectRatio == AspectRatio.device_16_9) {
            urlForBackgroundImage = payload.iPhone52xBackgroundImageURL
            urlForCompanyLogo = payload.iPhone2xCompanyLogoURL
        }

        brandingManager.urlForCompanyLogo = urlForCompanyLogo
        brandingManager.urlForBackgroundImage = urlForBackgroundImage

        _ = brandingManager.saveConsoleColor(payload.toolbarColor, key: AWColorKey.ToolbarColor)
        _ = brandingManager.saveConsoleColor(payload.toolbarTextColor, key: AWColorKey.ToolbarTextColor)
        _ = brandingManager.saveConsoleColor(payload.primaryColor, key: AWColorKey.PrimaryColor)
        _ = brandingManager.saveConsoleColor(payload.primaryTextColor, key: AWColorKey.PrimaryTextColor)
        _ = brandingManager.saveConsoleColor(payload.secondaryColor, key: AWColorKey.SecondaryColor)
        _ = brandingManager.saveConsoleColor(payload.secondaryTextColor, key: AWColorKey.SecondaryTextColor)

        brandingManager.managerProperties?.downloadAssetsAndNotifyBrandingUpdated {
            self.enforcementComplete()
        }
    }
}
