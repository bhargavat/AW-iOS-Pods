//
//  BrandingPayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

/**
 * @brief		Branding payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the branding group of an SDK profile.
 * @version     5.8
 */
@objc(AWBrandingPayload)
public class BrandingPayload: ProfilePayload {
    /** A boolean indicating if Branding is enabled. */
    public fileprivate (set) var enableBranding: Bool = false
    public fileprivate (set) var customBranding: Bool = false

    /** The Organization Name. */
    public fileprivate (set) var organizationName: String?

//Mark:- Colors
    /** The primary highlight color. */
    public fileprivate (set) var primaryHighlightColor: UIColor?
    public fileprivate (set) var primaryColor: UIColor?

    /** The secondary highlight color. */
    public fileprivate (set) var secondaryHighlightColor: UIColor?
    public fileprivate (set) var secondaryColor: UIColor?

    /** The navigation bar and toolbar color. */
    public fileprivate (set) var toolbarColor: UIColor?


//MARK:- Text Colors

    /** The primary text color. */
    public fileprivate (set) var primaryTextColor: UIColor?

    /** The secondary text color. */
    public fileprivate (set) var secondaryTextColor: UIColor?

    /**
     The login title text color.
     */
    public fileprivate (set) var loginTitleTextColor: UIColor?
    /** The tertiary text color. */
    public fileprivate (set) var tertiaryTextColor: UIColor?
    /** The toolbar text color. */
    public fileprivate (set) var toolbarTextColor: UIColor?


//MARK:- Background Images

    /** The background image for non-retina iPhones & iPod touches. */
    public fileprivate (set) var iPhoneBackgroundImageURL: URL?

    /** The background image for retina iPhones & iPod touches. */
    public fileprivate (set) var iPhone2xBackgroundImageURL: URL?

    public fileprivate (set) var iPhone52xBackgroundImageURL: URL?

    /** The background image for non-retina iPads. */
    public fileprivate (set) var iPadBackgroundImageURL: URL?

    /** The background image for retina iPads. */
    public fileprivate (set) var iPad2xBackgroundImageURL: URL?


//MARK:- Company Logo

    /** The company image logo for non-retina iPhones & iPod touches. */
    public fileprivate (set) var iPhoneCompanyLogoURL: URL?

    /** The company image logo for non-retina iPhones & iPod touches. */
    public fileprivate (set) var iPhone2xCompanyLogoURL: URL?

    /** The company image logo for non-retina iPads. */
    public fileprivate (set) var iPadCompanyLogoURL: URL?

    /** The company image logo for non-retina iPads. */
    public fileprivate (set) var iPad2xCompanyLogoURL: URL?


    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String: Any]) {
        super.init(dictionary: dictionary)

        self.enableBranding ??= dictionary.bool(for: BrandingPayloadConstants.kBrandingEnableBrandingKey)
        self.organizationName = dictionary[BrandingPayloadConstants.kBrandingOrganizationNameKey] as? String

        let brandingVersion: String? = dictionary[BrandingPayloadConstants.kPayloadTypeKey] as? String

        if (brandingVersion == BrandingPayloadConstants.kBrandingPayloadType) {
            parseColors(dictionary)
            parseTextColors(dictionary)
            parseBackgroundImages(dictionary)
            parseSecondaryImages(dictionary)
        }
    }

//MARK:- Payload Parsing Helper Methods
    internal func parseColors(_ dictionary: [String: Any]) {
        self.primaryHighlightColor = dictionary.color(for: BrandingPayloadConstants.kBrandingPrimaryColorKey)
        self.primaryColor = dictionary.color(for: BrandingPayloadConstants.kBrandingPrimaryColorKey)

        //check if the value is an empty string or an Int <= 0
        let primaryColorValueString = dictionary[BrandingPayloadConstants.kBrandingPrimaryColorKey] as? String

        //if primary color is not set in console then set it to AW_Blue else it takes black as default which becomes background color for Login and Passcode screens
        if primaryColorValueString != nil {
            self.primaryColor = dictionary.color(for: BrandingPayloadConstants.kBrandingPrimaryColorKey)
        }

        self.secondaryHighlightColor = dictionary.color(for: BrandingPayloadConstants.kBrandingSecondaryColorKey)
        self.secondaryColor = dictionary.color(for: BrandingPayloadConstants.kBrandingSecondaryColorKey)

        self.toolbarColor = dictionary.color(for: BrandingPayloadConstants.kBrandingToolbarColorKey)
    }

    internal func parseTextColors(_ dictionary: [String: Any]) {
        self.primaryTextColor = dictionary.color(for: BrandingPayloadConstants.kBrandingPrimaryTextColorKey)

        self.secondaryTextColor = dictionary.color(for: BrandingPayloadConstants.kBrandingSecondaryTextColorKey)

        self.toolbarTextColor = dictionary.color(for: BrandingPayloadConstants.kBrandingToolbarTextColorKey)
        self.tertiaryTextColor = toolbarTextColor
        self.loginTitleTextColor = toolbarTextColor
    }

    internal func parseBackgroundImages(_ dictionary: [String: Any]) {
        //iphone
        if let iphoneBGImage = dictionary[BrandingPayloadConstants.kBrandingBackgroundImageIphoneKey] as? String {
            self.iPhoneBackgroundImageURL = URL(string: iphoneBGImage)
        }
        if let iphoneBGImage2x = dictionary[BrandingPayloadConstants.kBrandingBackgroundImageIphone2XKey] as? String {
            self.iPhone2xBackgroundImageURL = URL(string: iphoneBGImage2x)
        }
        if let iphone5BGImage = dictionary[BrandingPayloadConstants.kBrandingBackgroundImageIphone52XKey] as? String {
            self.iPhone52xBackgroundImageURL = URL(string: iphone5BGImage)
        }
        //ipad
        if let ipadBGImage = dictionary[BrandingPayloadConstants.kBrandingBackgroundImageIpadKey] as? String {
            self.iPadBackgroundImageURL = URL(string: ipadBGImage)
        }

        if let ipadBGImage2x = dictionary[BrandingPayloadConstants.kBrandingBackgroundImageIpad2XKey] as? String {
            self.iPad2xBackgroundImageURL = URL(string: ipadBGImage2x)
        }
    }
    internal func parseSecondaryImages(_ dictionary: [String : Any]) {
        //iphone
        if let iphoneSecImage = dictionary[BrandingPayloadConstants.kBrandingSecondaryIphoneImageKey] as? String {
            self.iPhoneCompanyLogoURL = URL(string: iphoneSecImage)
        }
        if let iphoneSecImage2x = dictionary[BrandingPayloadConstants.kBrandingSecondaryIphoneImage2XKey] as? String {
            self.iPhone2xCompanyLogoURL = URL(string: iphoneSecImage2x)
        }
        //ipad
        if let ipadSecImage = dictionary[BrandingPayloadConstants.kBrandingSecondaryIpadImageKey] as? String {
            self.iPadCompanyLogoURL = URL(string: ipadSecImage)
        }
        if let ipadSecImage2x = dictionary[BrandingPayloadConstants.kBrandingSecondaryIpadImage2XKey] as? String {
            self.iPad2xCompanyLogoURL = URL(string: ipadSecImage2x)
        }
    }

//MARK:-
    override public class func payloadType() -> String {
        return BrandingPayloadConstants.kBrandingPayloadType
    }
}

internal extension Dictionary where Key == String {
    internal func color(for key: String) -> UIColor? {
        guard let number = self.int(for: key) else {
            return nil
        }
        return UIColor(number: number)
    }
}
