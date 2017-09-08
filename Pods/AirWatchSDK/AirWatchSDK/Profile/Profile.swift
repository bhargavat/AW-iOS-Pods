//
//  Profile.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

extension AWSDK {

    @objc(AWConfigurationProfileType)
    public enum ConfigurationProfileType: Int {
        @objc(AWConfigurationProfileUnknown)            case unknown            = 0
        @objc(AWConfigurationProfileAgent)              case agent              = 5
        @objc(AWConfigurationProfileBrowser)            case browser            = 7
        @objc(AWConfigurationProfileContentLocker)      case contentLocker      = 9
        @objc(AWConfigurationProfileSharedDevice)       case sharedDevice       = 13
        @objc(AWConfigurationProfileSDKV2)              case sdk                = 21
        @objc(AWConfigurationProfileSDKV2AppWrapping)   case sdkAppWrapping     = 22
        @objc(AWConfigurationProfileEmail)              case email              = 18
        @objc(AWConfigurationProfileBoxer)              case boxer              = 32


        /*
         * @method      StringValue
         * @abstract    Use this class method to get a string representation of a ConfigurationProfileType
         * @param       configurationType: A ConfigurationProfileType object
         * @return      returns a string representation of the given ConfigurationProfileType object
         */
        var StringValue: String {
            switch self {
            case .agent:            return "Agent"
            case .sdk:              return "SDK"
            case .browser:          return "Browser"
            case .contentLocker:    return "ContentLocker"
            case .sharedDevice:     return "SharedDevice"
            case .sdkAppWrapping:   return "SDKAppWrapping"
            case .boxer:            return "Boxer"
            case .email:            return "Email"
            default:                return "Unknown"
            }
        }

        /*
         * @method      fromString
         * @abstract    Use this class method to get a ConfigurationProfileType object from a string
         * @param       string: A string representation of a ConfigurationProfileType object
         * @return      returns a ConfigurationProfileType object corresponding to the given string or
         *              ConfigurationProfileType.Unknown if the string does not correspond to a ConfigurationProfileType
         */
        static func fromString(_ string: String) -> AWSDK.ConfigurationProfileType {
            switch string {
            case "Agent":                    return .agent
            case "SDK":                      return .sdk
            case "ContentLocker":            return .contentLocker
            case "Browser":                  return .browser
            case "SharedDevice":             return .sharedDevice
            case "Boxer":                    return .boxer
            case "SDKAppWrapping":           return .sdkAppWrapping
            default:                         return .unknown
            }
        }

        internal var servicesProfileType: AWServices.ConfigurationProfileType {
            switch self.StringValue {
            case "Agent":                    return AWServices.ConfigurationProfileType.agent
            case "SDK":                      return AWServices.ConfigurationProfileType.sdk
            case "ContentLocker":            return AWServices.ConfigurationProfileType.contentLocker
            case "Browser":                  return AWServices.ConfigurationProfileType.browser
            case "SharedDevice":             return AWServices.ConfigurationProfileType.sharedDevice
            case "Boxer":                    return AWServices.ConfigurationProfileType.boxer
            case "SDKAppWrapping":           return AWServices.ConfigurationProfileType.sdkAppWrapping
            default:                         return AWServices.ConfigurationProfileType.unknown
            }
        }
    }
}

/**
 * @brief		Represents an unmanaged configuration profile.
 * @details     Profile containing multiple payloads that are used to configure a device and application.
 * @version     6.0
 */
@objc(AWProfile)
public class Profile: NSObject {
    static fileprivate var info = mach_timebase_info(numer: 0, denom: 0)

    /** @name Generic Profile Information */
    public private (set) var displayName: String?
    public private (set) var comments: String?
    public private (set) var identifier: String?
    public private (set) var organization: String?
    public private (set) var uuid: String?
    public private (set) var version: Int?
    public internal (set) var profileType: AWSDK.ConfigurationProfileType = .unknown
    public private (set) var isSDKProfile: Bool = false
    public private (set) var timeStamp: TimeInterval?
    public private (set) var dictionaryToStore: [String: Any]
    /** The profile groups enclosed within the profile. */
    public private (set) var appPayloads: [ProfileGroup]

    /** The profile groups enclosed within the profile. */
    @available(*, deprecated: 6.0, message: "Use appPayloads instead")
    public private (set) var payloads: Array<ProfileGroup> {
        get {
            return appPayloads
        }
        set {
            appPayloads = newValue
        }
    }

    /** @name SDK Profile Payloads */
    public private (set) var geofencePayload: GeofencePayload?
    public private (set) var analyticsPayload: AnalyticsPayload?
    public private (set) var restrictionsPayload: RestrictionsPayload?
    public private (set) var compliancePayload: CompliancePayload?
    public private (set) var authenticationPayload: AuthenticationPayload?
    public private (set) var brandingPayload: BrandingPayload?
    public private (set) var breezyPayload: BreezyPayload?
    public private (set) var customPayload: CustomPayload?
    public private (set) var offlineAccessPayload: OfflineAccessPayload?
    public private (set) var networkAccessPayload: NetworkAccessPayload?
    public private (set) var contentFilteringPayload: ContentFilteringPayload?
    public private (set) var websiteFilteringPayload: WebsiteFilteringPayload?

    internal var proxyPayload: SDKProxyPayload?
    internal var loggingPayload: LoggingPayload?
    internal var certificatePayload: SDKCertificatePayload?
    internal var identityPayload: IdentityPayload?

    internal static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = ProfileConstants.kProfileTimeStampFormat
        return formatter
    }()

    @objc(initWithInfo:)
    public init(info: [String: Any]) {
        self.appPayloads = []
        dictionaryToStore = info
        super.init()

        if let typeIntValue: Int = info[ProfileConstants.kConfigurationProfileType] as? Int {
            profileType = AWSDK.ConfigurationProfileType(rawValue: typeIntValue) ?? profileType
        }

        if let fetchTimeStamp: String = dictionaryToStore[ProfileConstants.kProfileTimeStamp] as? String {///if there is not a timeStamp value already create one
            timeStamp = Profile.timestampFormatter.date(from: fetchTimeStamp)?.timeIntervalSince1970
        }

        displayName = info[ProfileConstants.kPayloadDisplayName] as? String
        comments = info[ProfileConstants.kPayloadDescription] as? String
        identifier = info[ProfileConstants.kPayloadIdentifier] as? String
        organization = info[ProfileConstants.kPayloadOrganization] as? String
        uuid = info[ProfileConstants.kPayloadUUID] as? String
        version = info[ProfileConstants.kPayloadVersion] as? Int

        if let payloadContent: [[String: AnyObject]] = info[ProfileConstants.kPayloadContent] as? [[String: AnyObject]] {
            for payloadInfo: [String: AnyObject] in payloadContent {
                if payloadInfo.count > 0 {///if there is anything in this payload
                    processPayload(payloadInfo)
                }
            }
        } else {
            AWLogError("Error Parsing Profile: Missing Payload Content in given dictionary")
        }

        if isSDKProfile || profileType == AWSDK.ConfigurationProfileType.sdk {
            isSDKProfile = true
            profileType = AWSDK.ConfigurationProfileType.sdk
            log(debug: "SDK Profile Created")
        } else {
            log(debug: "App Profile Created")
        }
    }

    internal convenience init?(profileData: Data, profileType: AWSDK.ConfigurationProfileType = .unknown) {
        var format = PropertyListSerialization.PropertyListFormat.xml
        var plist: Any? = nil
        do {
            plist = try PropertyListSerialization.propertyList(from: profileData, options: .mutableContainersAndLeaves, format: &format)
        }
        catch{
            print("Error reading plist: \(error), format: \(format)")
            return nil
        }

        guard var profileInfo = plist as? [String: AnyObject] else {
            return nil
        }

        profileInfo[ProfileConstants.kConfigurationProfileType] = profileType.rawValue as AnyObject
        if profileInfo[ProfileConstants.kProfileTimeStamp] == nil {
            profileInfo[ProfileConstants.kProfileTimeStamp] = Profile.timestampFormatter.string(from: Date()) as AnyObject
        }
        self.init(info: profileInfo)
    }

    fileprivate func processPayload(_ payloadInfo: [String: Any]) -> Void {
        var payloadTypeString: String = "" //empty String goes to default case in switch statement
        if let tmpString: String = payloadInfo[ProfileConstants.kPayloadType] as? String {
            payloadTypeString = tmpString
        }

        switch payloadTypeString {
        case AnalyticsPayload.payloadType():
            analyticsPayload = AnalyticsPayload(dictionary: payloadInfo)

        case AuthenticationPayload.payloadType():
            authenticationPayload = AuthenticationPayload(dictionary: payloadInfo)

        case BrandingPayload.payloadType():
            brandingPayload = BrandingPayload(dictionary: payloadInfo)

        case BreezyPayload.payloadType():
            breezyPayload = BreezyPayload(dictionary: payloadInfo)

        case SDKCertificatePayload.payloadType():
            certificatePayload = SDKCertificatePayload(dictionary: payloadInfo)

        case CompliancePayload.payloadType():
            compliancePayload = CompliancePayload(dictionary: payloadInfo)

        case ContentFilteringPayload.payloadType():
            contentFilteringPayload = ContentFilteringPayload(dictionary: payloadInfo)

        case CustomPayload.payloadType():
            customPayload = CustomPayload(dictionary: payloadInfo)

        case GeofencePayload.payloadType():
            geofencePayload = GeofencePayload(dictionary: payloadInfo)

        case IdentityPayload.payloadType():
            identityPayload = IdentityPayload(dictionary: payloadInfo)

        case LoggingPayload.payloadType():
            loggingPayload = LoggingPayload(dictionary: payloadInfo)

        case NetworkAccessPayload.payloadType():
            networkAccessPayload = NetworkAccessPayload(dictionary: payloadInfo)

        case OfflineAccessPayload.payloadType():
            offlineAccessPayload = OfflineAccessPayload(dictionary: payloadInfo)

        case SDKProxyPayload.payloadType():
            proxyPayload = SDKProxyPayload(dictionary: payloadInfo)

        case RestrictionsPayload.payloadType():
            restrictionsPayload = RestrictionsPayload(dictionary: payloadInfo)
        case WebsiteFilteringPayload.payloadType():
            websiteFilteringPayload = WebsiteFilteringPayload(dictionary: payloadInfo)
        default:
            log(debug: "Parsing Profile: Unknown Payload Type: \(payloadTypeString)")
            /// Handling custom App payloads
            if payloadTypeString.characters.count > 0 {
                log(debug: "Parsing Profile: Adding Unknown Payload Type: \(payloadTypeString) to Profile's appPayloads")
                let profileGroup: ProfileGroup = ProfileGroup(info: payloadInfo)
                appPayloads.append(profileGroup)
            }
            return
        }
        isSDKProfile = true
    }
}

extension Profile {
    @objc
    public func toDictionary() -> [String: Any] {
        return self.dictionaryToStore
    }
}

extension Profile {
    @objc
    override public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? Profile {
            return displayName == object.displayName &&
                comments == object.comments &&
                identifier == object.identifier &&
                organization == object.organization &&
                uuid == object.uuid &&
                version == object.version &&
                profileType == object.profileType &&
                isSDKProfile == object.isSDKProfile &&
                timeStamp == object.timeStamp &&
                appPayloads == object.appPayloads &&
                NSDictionary(dictionary:dictionaryToStore).isEqual(to: object.dictionaryToStore) &&
                geofencePayload == object.geofencePayload &&
                analyticsPayload == object.analyticsPayload &&
                restrictionsPayload == object.restrictionsPayload &&
                compliancePayload == object.compliancePayload &&
                authenticationPayload == object.authenticationPayload &&
                brandingPayload == object.brandingPayload &&
                customPayload == object.customPayload &&
                loggingPayload == object.loggingPayload &&
                offlineAccessPayload == object.offlineAccessPayload &&
                proxyPayload == object.proxyPayload &&
                certificatePayload == object.certificatePayload &&
                networkAccessPayload == object.networkAccessPayload &&
                identityPayload == object.identityPayload &&
                contentFilteringPayload == object.contentFilteringPayload &&
                websiteFilteringPayload == object.websiteFilteringPayload
        } else {
            return false
        }
    }
}

extension Profile: PropertyInfo {
    @objc
    override public var description: String {
        get {
            let nilString : String = "nil"
            let displayNameString = displayName ?? nilString
            let commentsString = comments ?? nilString
            let identifierString = identifier ?? nilString
            let organizationString = organization ?? nilString
            let uuidString = uuid ?? nilString
            let versionString = (version != nil) ? String(describing: version!) : nilString
            let profileTypeString = "\(profileType)" + "(\(profileType.rawValue))"
            let timeStampString = (timeStamp != nil) ? String(describing: timeStamp!) : nilString
            
            let descriptionPrefix: String  = "\nProfile Description:\n" +
                                             "\t- displayName: \(displayNameString)\n" +
                                             "\t- comments: \(commentsString)\n" +
                                             "\t- identifier: \(identifierString)\n" +
                                             "\t- organization: \(organizationString)\n" +
                                             "\t- uuid: \(uuidString)\n" +
                                             "\t- version: \(versionString)\n" +
                                             "\t- profileType: \(profileTypeString)\n" +
                                             "\t- isSDKProfile: \(isSDKProfile)\n" +
                                             "\t- appPayloads: \(appPayloads)\n" +
                                             "\t- timeStamp: \(timeStampString)\n"
            
            return self.propertiesInfo().filter { $0.0.hasSuffix("Payload") }.flatMap {
                let (name, value, _) = $0
                let result = (value as AnyObject).description ?? ""
                return "\n\t \(name): " + result + "\n"
                }.reduce(descriptionPrefix, +)
        }
    }
}

extension Profile {
    public var domainsToTunnel: [String] {
        if let domains = self.proxyPayload?.appTunnelDomains as? [String] {
            return domains
        }

        return []
    }
}

extension Profile {
    public class func fromData(_ data: Data) -> Profile? {
        do {
            let profileDictionary: [String: Any] = try Dictionary.dictionaryFromPropertyListData(data)
            return Profile(info: profileDictionary)
        } catch {
            AWLogError("Error: Failed to construct profile dictionary from data")
            return nil
        }
    }

    public func toData () -> Data? {
        let profileDictionary: [String: Any] = self.dictionaryToStore
        do {
            return try profileDictionary.propertyListDataFromDictionary()
        } catch {
            AWLogError("Error: Failed to convert profile dictionary into property list")
            return nil
        }
    }
}
