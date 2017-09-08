//
//  SDKDefaultSettings.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

internal let MockSimulatorUDID = "AWMockSimulatorUDID"
internal let SDKDefaultBundleName = "AWSDKDefaults"
internal let SDKDefaultSetingsFileName = "AWSDKDefaultSettings"
internal let ToggleAuthorizationTokenViewKey = "AWToggleAuthorizationTokenViewKey"
internal let WorkOfflineButtonVisibilityKey = "kAWWorkOnlineButtonVisibilityKey"
internal let DataUsageEnabled = "AWDataUsageEnabled"
internal let DataUsageConfiguration = "AWDataUsageConfiguration"
internal let LogInsight = "LogInsight"
internal let SDKHeartBeatInterval = "AWSDKHeartBeatInterval"
internal let SDKDataSampleInterval = "AWSDKDataSampleInterval"
internal let SDKDataTransmitInterval = "AWSDKDataTransmitInterval"
internal let SAMLAuthenticationEnabled = "AWSAMLAuthenticationEnabled"
internal let ClipboardEnabled = "AWClipboardEnabled"
internal let RedirectComposeEmailConfiguration = "AWMailtoSchemeConfiguration"
internal let RedirectWebURLConfiguration = "AWURLSchemeConfiguration"
internal let SSLPinningDict = "SSLPinning"
internal let SSLPinningEnabled = "isPinningEnabled"
internal let SSLPinningQaEnvironment = "isQaEnvironment"
internal let SSLPinningSoftFail = "isSoftTrustFail"
internal let HTTPMAGTestURLEnabled = "AWHTTPMAGTestURLEnabled"
internal let ThirdPartyKeyboardEnabled = "AWThirdPartyKeyboardEnabled"
internal let MixpanelEnabled = "AWMixpanelEnabled"

internal let TestEnrollmentServerURL = "com.vmware.air-watch.enrollment.test-server-url"
internal let TestEnrollmentOrganizationGroup = "com.vmware.air-watch.enrollment.test-org-group-id"

protocol SDKSettingHandler {
    var plistDictionary: NSDictionary? { get }
}

@objc
public class SDKDefaultSettings: NSObject, SDKSettingHandler {
    // necessary to be public so that objective-c can see this variable and modify it in unit tests
    public var plistDictionary: NSDictionary?
    public var plistBundle: Bundle?

    static open let sharedSettings = SDKDefaultSettings()

    private override init() {
        super.init()

        if let plistBundlePath = Bundle.main.path(forResource: SDKDefaultBundleName, ofType: "bundle"),
            let plistBundle = Bundle(path: plistBundlePath),
            let plistFilePath = plistBundle.path(forResource: SDKDefaultSetingsFileName, ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistFilePath) {

            self.plistDictionary = plist
            self.plistBundle = plistBundle
        }
    }

    /**
     Specify in SDKDefaultSettings.plist a String value for key AWMockSimulatorUDID
     
     @return Default value is nil if not specified
     */
    public func mockedSimulatorUDID() -> String? {
        return self.plistDictionary?[MockSimulatorUDID] as? String
    }

    /**
     Specify in SDKDefaultSettings.plist a bool value for key AWToggleAuthorizationTokenViewKey
     
     @return Default value is false
     */
    public func isAuthorizationTokenButtonVisible() -> Bool {
        if let obj = plistDictionary?[ToggleAuthorizationTokenViewKey] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }

    /**
     Specify in SDKDefaultSettings.plist a bool value for key kAWWorkOnlineButtonVisibilityKey
     
     @return Default value is false
     */
    public func isWorkOnlineButtonVisible() -> Bool {
        if let obj = plistDictionary?[WorkOfflineButtonVisibilityKey] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }

    /**
     Specify in SDKDefaultSettings.plist a bool value for key AWDataUsageEnabled
     
     @return Default value is false
     */
    public func isDataUsageEnabled() -> Bool {
        if let obj = plistDictionary?[DataUsageEnabled] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }

    public func getDataUsageConfiguration() -> NSDictionary? {
        return plistDictionary?.object(forKey: DataUsageConfiguration) as? NSDictionary
    }

    /**
     Specify in SDKDefaultSettings.plist a bool value for key AWClipboardEnabled
     
     @return Default value is false
     */
    public func isAirWatchClipboardEnabled() -> Bool {
        if let obj = plistDictionary?[ClipboardEnabled] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }

    public func isRedirectComposeEmailEnabled() -> Bool {
        if let configuration = getRedirectComposeEmailConfiguration() {
            if let enabled = configuration["enabled"] as? Bool {
                return enabled
            }
        }
        return false
    }
    
    public func getRedirectComposeEmailConfiguration() -> NSDictionary? {
        return plistDictionary?.object(forKey: RedirectComposeEmailConfiguration) as? NSDictionary
    }

    public func isRedirectWebURLEnabled() -> Bool {
        if let configuration = getRedirectWebURLConfiguration() {
            if let enabled = configuration["enabled"] as? Bool {
                return enabled
            }
        }
        return false
    }
    
    public func getRedirectWebURLConfiguration() -> NSDictionary? {
        return plistDictionary?.object(forKey: RedirectWebURLConfiguration) as? NSDictionary
    }

    public func isSAMLAuthenticationEnabled() -> Bool {
        if let obj = plistDictionary?[SAMLAuthenticationEnabled] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }

    public func sharedAWKitBundle() -> Bundle? {
        guard let resourcePath = Bundle.main.resourcePath else {
            return nil
        }
        let bundlePath = resourcePath + "AWKit.bundle"
        
        return Bundle(path: bundlePath)
    }

    public func getLogInsightURLDefaults() -> NSDictionary? {
        return plistDictionary?.object(forKey: LogInsight) as? NSDictionary
    }

    public func heartBeatInterval() -> NSInteger {
        if let id = plistDictionary?.object(forKey: SDKHeartBeatInterval) {
            if id is String {
                return Int(id as! String)!
            } else if id is NSNumber {
                return Int(id as! NSNumber)
            }
        }
        return 0
    }

    public func sampleInterval() -> NSInteger {
        if let id = plistDictionary?.object(forKey: SDKDataSampleInterval) {
            if id is String {
                return Int(id as! String)!
            } else if id is NSNumber {
                return Int(id as! NSNumber)
            }
        }

        return 300 // 5 * 60 => 5 Minutes//
    }
    
    /**
     Specify in SDKDefaultSettings.plist an int value for key AWSDKDataTransmitInterval
     
     @return Default value is 7200
     */
    public func transmitInterval() -> NSInteger {
        if let id = plistDictionary?.object(forKey: SDKDataTransmitInterval) {
            if id is String {
                return Int(id as! String)!
            } else if id is NSNumber {
                return Int(id as! NSNumber)
            }
        }
        return 7200 // 2 * 60 * 60 => 2 hours//
    }

    public func brandingDictionary() -> NSDictionary? {
        guard let sdkDefaultsPlistForBranding = plistDictionary?["Branding"] else {
            return nil
        }
        return sdkDefaultsPlistForBranding as? NSDictionary
    }

    public func isQAEnvironment() -> Bool {
        guard let sdkDefaultsPlistForBranding = plistDictionary?[SSLPinningDict] else {
            return false
        }
        guard let settingsDict = sdkDefaultsPlistForBranding as? NSDictionary else {
            return false
        }
        guard let isQaEnv = settingsDict[SSLPinningQaEnvironment] as? Bool else {
            return false
        }
        return isQaEnv
    }

    public func isSSLPinningEnabled() -> Bool {
        guard let sdkDefaultsPlistForBranding = plistDictionary?[SSLPinningDict] else {
            return true
        }
        guard let settingsDict = sdkDefaultsPlistForBranding as? NSDictionary else {
            return true
        }
        guard let isEnabled = settingsDict[SSLPinningEnabled] as? Bool else {
            return true
        }
        return isEnabled
    }

    public func isSSLPinningSoftFail() -> Bool {
        guard let sdkDefaultsPlistForBranding = plistDictionary?[SSLPinningDict] else {
            return false
        }
        guard let settingsDict = sdkDefaultsPlistForBranding as? NSDictionary else {
            return false
        }
        guard let isSoftFail = settingsDict[SSLPinningSoftFail] as? Bool else {
            return false
        }
        return isSoftFail
    }
    
    /**
     Specify in SDKDefaultSettings.plist a bool value for key AWHTTPMAGTestURLEnabled
     
     @return Default value is false
     */
    public func isHTTPMAGTestURLEnabled() -> Bool {
        if let obj = plistDictionary?[HTTPMAGTestURLEnabled] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }
    
    /**
     Specify in SDKDefaultSettings.plist a bool value for key AWThirdPartyKeyboardEnabled
     
     @return Default value is false
     */
    public func isThirdPartyKeyboardEnabled() -> Bool {
        if let obj = plistDictionary?[ThirdPartyKeyboardEnabled] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return false
    }
    
    /** 
     Specify in SDKDefaultSettings.plist a bool value for key AWMixpanelEnabled
     
     @return Default value is true
     */
    public func isMixpanelEnabled() -> Bool {
        if let obj = plistDictionary?[MixpanelEnabled] {
            if let b = (obj as? Bool) {
                return b
            }
        }
        return true
    }

    /**
     Returns an enrollment server url that will let user enroll through a third party app.

     @return Default value is nil.
     */
    public func testEnrollmentServerURL() -> String? {
        guard let testEnrollmentServerURL = plistDictionary?[TestEnrollmentServerURL] else {
            return nil
        }

        return testEnrollmentServerURL as? String
    }

    /**
     Returns an enrollment org. group that will let user enroll through a third party app.

     @return Default value is nil.
     */
    public func testEnrollmentOrganizationGroup() -> String? {
        guard let testEnrollmentOrgGroup = plistDictionary?[TestEnrollmentOrganizationGroup] else {
            return nil
        }

        return testEnrollmentOrgGroup as? String
    }

}
