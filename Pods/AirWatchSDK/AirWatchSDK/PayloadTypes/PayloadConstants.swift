//
//  ProfileManagerConstants.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

class ProfileGroupConstants {
    static let kPayloadDisplayName: String  = "PayloadDisplayName"
    static let kPayloadDescription: String  = "PayloadDescription"
    static let kPayloadIdentifier: String   = "PayloadIdentifier"
    static let kPayloadOrganization: String = "PayloadOrganization"
    static let kPayloadType: String         = "PayloadType"
    static let kPayloadUUID: String         = "PayloadUUID"
    static let kPayloadVersion: String      = "PayloadVersion"
}

class ProfileConstants {
    static let kPayloadDescription: String      = "PayloadDescription"
    static let kPayloadDisplayName: String      = "PayloadDisplayName"
    static let kPayloadIdentifier: String       = "PayloadIdentifier"
    static let kPayloadOrganization: String     = "PayloadOrganization"
    static let kPayloadType: String             = "PayloadType"
    static let kPayloadUUID: String             = "PayloadUUID"
    static let kPayloadVersion: String          = "PayloadVersion"
    static let kPayloadContent: String          = "PayloadContent"
    static let kSDKCustomSettings: String       = "SdkCustomSettings"
    static let kProfileTimeStamp: String        = "ProfileTimeStamp"
    static let kProfileTimeStampFormat: String  = "E, dd MM yyyy HH:mm:ss Z"
    static let kConfigurationProfileType: String  = "ConfigurationProfileType"

    static let kAWAgentSettingsPayloadType: String		= "com.apple.settings.agent"
    static let kAWSharedDeviceSettingsPayloadType: String		= "com.air-watch.shareddevice"
    static let kAWBrowserSecuritySettingsPayloadType: String = "browserSecuritySettings"
    static let kAWContentSettingsPayloadType: String = "contentManagementSettings"
    static let kAWChatSettingsPayloadType: String = "com.air-watch.gather"
    static let kAWEmailSettingsPayloadType: String = "com.airwatch.apple.awemailclient"
}

class IdentityPayloadConstants {
    static let kCertificateGuid: String = "CertificateIssuer"
    static let kIssuerToken: String = "IssuerToken"
    static let kIdentityPayloadType: String = "CertificateSettingsV2"
}

class ContentFilteringPayloadConstants {
    static let kContentFilteringPayloadType: String = "ContentFiltering"
    static let kContentFilteringWebsenseAccountId: String = "WebsenseAccountId"
    static let kContentFilteringWebsensePacAddress: String = "WebsenseDefaultPacAddress"
    static let kContentFilteringWebsenseProxyType: String = "WebsenseProxyType"
    static let kContentFilteringWebsenseSecurityKey: String = "WebsenseSecurityKey"
    static let kContentFilteringWebsenseProxyTypeId: String = "WebsenseProxyType"
}

class WebsiteFilteringPayloadConstants {
    static let kWebsiteFilteringPayloadType: String = "WebsiteFiltering"
    static let kWebsiteFilteringWebsiteFilterId: String = "WebsiteFilterId"
    static let kWebsiteFilteringWebsiteFilterCategories: String = "WebsiteFilterCategories"
    static let kWebsiteFilteringFilterTypeId: String = "FilterTypeId"
}

class AnalyticsPayloadConstants {
    static let kAnaltyicsPayloadType: String = "AnalyticsSettingsV2"
    static let kAnalyticsPayloadEnabled: String = "EnableAnalytics"
}

class AuthenticationPayloadConstants {
    static let kAuthenticationPayloadType: String = "PasscodePoliciesV2"

    static let kAuthenticationPasscodeMode: String = "PasscodeMode"
    static let kAuthenticationAllowSimple: String  = "AllowSimple"
    static let kAuthenticationMinimumPasscodeLenth: String = "MinimumPasscodeLength"
    static let kAuthenticationMinimumComplexChars: String = "MinimumNumberComplexCharacters"
    static let kAuthenticationMaximumPasscodeAge: String = "MaximumPasscodeAge"
    static let kAuthenticationMinimumUniquePasscodesBeforeReuse: String = "PasscodeHistory"
    static let kAuthenticationMaximumFailedAttempts: String = "MaximumFailedAttempts"
    static let kAuthenticationPasscodeTimeout: String = "PasscodeTimeout"
    static let kAuthenticationPolicyId: String = "policyId"
    static let kAuthenticationSingleSignOnEnabled: String = "EnableSingleSignOn"
    static let kIntegratedAuthenticationEnabled: String = "EnableIntegratedAuthentication"
    static let kIntegratedAutheAllowedSitesKey: String = "AllowedSites"
    static let kAuthenticationTypeKey: String = "AuthenticationType"
    static let kBiometricModeKey = "BiometricMode"
}

class ProxyPayloadConstants {
    static let kProxyPayloadType: String      = "AppTunnelingPoliciesV2"
    static let kProxyEnableProxy: String      = "EnableAppTunnel"
    static let kProxyType: String             = "AppTunnelMode"

    static let kProxyMAGServerURL: String     = "MAGProxyServer"
    static let kProxyMAGHTTPPort: String      = "MAGHttpPort"
    static let kProxyMAGHTTPSPort: String     = "MAGHttpsPort"
    static let kProxyMAGUsePublicSSL: String    = "MAGUsePublicSSL"
    static let kMAGProxySSLCertificate: String  = "MAGSslCertificate"

    static let kProxyEnableF5: String           = "EnableF5Integration"
    static let kProxyF5UseAuth: String          = "F5UseAuthentication"
    static let kProxyF5Port: String             = "F5ProxyPort"
    static let kProxyF5AccountType: String      = "F5UserAccountType"
    static let kProxyF5AccountName: String      = "F5Username"
    static let kProxyF5AccountPass: String      = "F5Password"
    static let kProxyF5AuthMode: String         = "F5AuthenticationMode"
    static let kProxyF5Host: String             = "F5ProxyServer"

    static let kProxyStandardUseAuth: String    = "UseAuthentication"
    static let kProxyStandardUsername: String   = "Username"
    static let kProxyStandardPassword: String   = "Password"
    static let kProxyStandardPort: String       = "ProxyPort"
    static let kProxyStandardProxyURL: String   = "ProxyUrl"
    static let kProxyStandardURLSource: String  = "UrlSource"
    static let kProxyStandardAutoConfig: String = "AutoConfig"

    static let kProxyAppTunnelDomains: String   = "AppTunnelDomains"
    static let kProxyMagRSAAdaptiveAuthEnabled: String = "MagRsaAdaptiveAuthEnabled"
}

class BrandingPayloadConstants {
    // Payload type values
    static let kBrandingPayloadType: String				= "BrandingSettingsV2"

    static let kBrandingEnableBrandingKey: String		= "EnableBranding"
    static let kBrandingOrganizationNameKey: String		= "OrganizationName"

    // Color Keys
    static let kBrandingToolbarColorKey: String			= "ToolbarColor"
    static let kBrandingPrimaryColorKey: String			= "PrimaryColor"
    static let kBrandingSecondaryColorKey: String		= "SecondaryColor"

    // Text Color keys
    static let kBrandingPrimaryTextColorKey: String		= "PrimaryTextColor"
    static let kBrandingSecondaryTextColorKey: String	= "SecondaryTextColor"
    static let kBrandingTertiaryTextColorKey: String		= "TertiaryText"
    static let kBrandingLoginTitleTextColorKey: String		= "LoginTitleText"
    static let kBrandingToolbarTextColorKey: String		= "ToolbarTextColor"

    // Background Images
    static let kBrandingBackgroundImageIpadKey: String	= "BackroundImageiPad"
    static let kBrandingBackgroundImageIpad2XKey: String	= "BackroundImageiPadHighRes"
    static let kBrandingBackgroundImageIphoneKey: String	= "BackroundImageiPhone"
    static let kBrandingBackgroundImageIphone2XKey: String	= "BackroundImageiPhoneHighRes"
    static let kBrandingBackgroundImageIphone52XKey: String	= "BackroundImageiPhone5HighRes"

    // Secondary Image
    static let kBrandingSecondaryIphoneImageKey: String	= "CompanyLogoPhone"
    static let kBrandingSecondaryIphoneImage2XKey: String = "CompanyLogoPhoneHighRes"
    static let kBrandingSecondaryIpadImageKey: String	= "CompanyLogoTablet"
    static let kBrandingSecondaryIpadImage2XKey: String	= "CompanyLogoTabletHighRes"

    // Payload Key
    static let kPayloadTypeKey: String = "PayloadType"
}

class BreezyPayloadConstants {
    static let kIntegrationServicesPayloadTypeV2 = "IntegrationServices"
    static let kIntegrationServicesBreezyMDMAuthToken = "BreezyMDMAuthToken"
    static let kIntegrationServicesBreezyServerUrl = "BreezyServerUrl"
    static let kIntegrationServicesEnabled = "EnableIntegrationServices"
    static let kIntegrationServicesBreezyOauthConsumerID = "BreezyOauthConsumerID"
    static let kIntegrationServicesbreezyOauthConsumerSecret = "BreezyOauthConsumerSecret"
}

class CertificatePayloadConstants {
    static let kCertificatePayloadType: String	= "CredentialsSettingsV2"
    static let kCertificatePayloadData: String		= "PayloadContent"
    static let kCertificatePayloadName: String		= "CertificateName"
    static let kCertificatePayloadPassword: String	= "Password"
    static let kCertificatePayloadThumbprint: String  = "CertificateThumbprint"
    static let kCertificatePayloadCertificateType: String = "CertificateType"
}

class CompliancePayloadConstants {
    static let kCompliancePreventCompromisedKey: String                = "preventCompromisedDevices"
    static let kCompliancePreventBackupRestoreKey: String              = "preventRestoringBackupDevices"
    static let kComplianceAWComplianceCompromisedActionsKey: String    = "AWComplianceCompromisedActions"

    static let kCompliancePayloadType: String                 = "CompromisedPoliciesV2"
    static let kComplianceCompromisedProtectionKey: String      = "CompromisedProtection"
    static let kCompliancePolicyID: String                      = "policyID"
}

class CustomPayloadConstants {
    static let kCustomPayloadType: String = "CustomSettingsV2"

    static let kCustomSettingsKey: String = "CustomSettings"
}

class GeofencePayloadConstants {

    static let kGeofencePayloadType: String = "GeofencingSettingsV2"
    static let kPayloadType: String         = "PayloadType"

    static let kGeofencePayloadIsEnabled: String = "EnableGeofencing"

    static let kGeofencePayloadAreas: String = "GeofenceAreas"

    static let kGeofencePayloadAreaCenterX: String = "CenterX"
    static let kGeofencePayloadAreaCenterY: String = "CenterY"
    static let kGeofencePayloadAreaRadius: String = "Radius"
    static let kGeofencePayloadAreaName: String = "Name"
    static let kGeofencePayloadAreaID: String = "UniqueId"
}

class IntegratedAuthPayloadConstants {
    static let kIntegratedAuthPayloadType: String		 = "IntegratedAuthenticationV2"
    static let kIntegratedAuthenticationEnabled: String  = "EnableIntegratedAuthentication"
    static let kIntegratedAutheAllowedSitesKey: String   = "AllowedSites"
}

class NetworkAccessPayloadConstants {
    static let kNetworkAccessPayloadType: String = "NetworkAccessV2"
    static let kNetworkAccessEnabled: String        = "EnableNetworkAccess"
    static let kNetworkAccessAllowCellular: String  = "AllowCellularConnection"
    static let kNetworkAccessAllowWiFi: String      = "AllowWiFiConnection"
    static let kNetworkAccessAllowedSSIDs: String   = "AllowedSSIDs"
}

class OfflineAccessPayloadConstants {
    static let kAWOfflineAccessPayloadType: String		 = "OfflineAccessPoliciesV2"
    static let kAWOfflineAccessEnabledKey: String        = "EnableOfflineAccess"
    static let kAWOfflineMaximumPeriodAllowedKey: String = "MaximumPeriodAllowedOffline"
}

class SSLPinningPayloadConstants {
    static let kSSLPinningPayloadType: String = "SSLPinningV2"
    static let kDomain: String = "DomainName"
    static let kCertData: String = "Certificate"
    static let kThumbPrint: String = "SHA1"
    static let kIncludeSubDomains: String = "IncludeSubdomains"
    static let kStrict: String = "Strict"
}

class RestrictionsPayloadConstants {
    static let kRestrictionsPayloadType: String				= "DataLossPreventionV2"
    static let kPayloadType: String         = "PayloadType"

    // Offline restrictions
    static let kRestrictionsAllowOfflineModeKey: String			= "allowOfflineMode"
    static let kRestrictionsMaxOfflineDurationKey: String		= "MaximumPeriodAllowedOffline"
    static let kRestrictionsMaxOfflineUsesKey: String			= "MaximumSuccessfulLoginsAllowedOffline"
    static let kRestrictionsOfflineLimitActionsKey: String      = "AWAccessControlOfflineLimitActions"

    // MDM Enrollment
    static let kRestrictionsRequireMDMKey: String				= "requireMDMEnrollment"
    static let kRestrictionsDeviceNotEnrolledActionsKey: String	= "AWAccessControlNotEnrolledActions"

    // Open in Restrictions
    static let kRestrictDocumentsToApps: String               = "LimitDocumentstoOpenOnlyinApprovedApps"
    static let kAllowedApplications: String                     = "AllowedApplications"

    // Copy paste cut
    static let kRestrictionsPreventCopyAndCutKey: String      = "EnableCopyPaste"

    // Printing
    static let kRestrictionsEnablePrinting: String            = "EnablePrinting"

    // Data Loss Prevention
    static let kRestrictionsEnableDataLossPrevention: String  = "EnableDataLossPrevention"

    static let kRestrictionsEnableEmailComposing: String        = "EnableComposingEmail"
    static let kRestrictionsEnableLocationReporting: String     = "EnableLocationServices"
    static let kRestrictionsEnableCameraAccess: String          = "EnableCamera"
    static let kRestrictionsEnableDataBackUp: String            = "EnableDataBackUp"

    // Watermark
    static let kRestrictionsEnableWatermark: String           = "EnableWatermark"
    static let kRestrictionsWatermarkOverlay: String          = "OverlayText"
}

class LoggingPayloadConstants {
    static let kAWLoggingPayloadType: String 			= "LoggingSettingsV2"
    static let kAWLoggingLoggingLevelKey: String 		= "LoggingLevel"
    static let kAWLoggingSendLogsOverWifiKey: String 	= "SendLogsOverWifi"
}

