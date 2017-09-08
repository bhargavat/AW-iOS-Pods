//
//  SendBeaconEndpoint.swift
//  BeaconEndpoint
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import AWHelpers
import AWCrypto
import AWError
import CoreLocation
import Foundation

extension AWServices {

    //MARK: Public Beacon types
    public enum SendBeaconPayload {
        case ping

        case generalInfo(APNToken: String?, locationGroup: String?, transID: String?)

        case userInfo(email: String?, phone: String?)

        case gpsInfo(latitude: CLLocationDegrees?,
                     longitude: CLLocationDegrees?,
                     altitude: CLLocationDegrees?,
                     speed: CLLocationSpeed?,
                     locationSampleDate: Date?)

        case compliancePolicies(policies: [(policyIdentifier: String, complianceStatus: Int)]?)

        indirect
        case combination(general: SendBeaconPayload?, user: SendBeaconPayload?, gps: SendBeaconPayload?, compliancePolicies: SendBeaconPayload?)

        func internalPayloadType(_ deviceUDID: String) -> BeaconPayloadType {
            switch self {
            case .ping:
                return .ping(deviceUDID: deviceUDID)

            case let .generalInfo(token, locationGroup, transID):
                return .generalInfo(deviceUDID: deviceUDID, APNToken: token, locationGroup: locationGroup, transID: transID)

            case let .userInfo(email, phone):
                return .userInfo(deviceUDID: deviceUDID, email: email, phone: phone)

            case let .gpsInfo(lat, longt, alt, speed, locDate):
                return .GPSInfo(deviceUDID: deviceUDID, latitude: lat, longitude: longt, altitude: alt, speed: speed, locationSampleDate: locDate)

            case let .compliancePolicies(policies):
                return .CompliancePolicies(deviceUDID: deviceUDID, policies: policies)

            case let .combination(general, user, gps, compliancePolicies):
                return .combination(deviceUDID: deviceUDID,
                                    general: general?.internalPayloadType(deviceUDID),
                                    user: user?.internalPayloadType(deviceUDID),
                                    gps: gps?.internalPayloadType(deviceUDID),
                                    compliancePolicies: compliancePolicies?.internalPayloadType(deviceUDID))
            }
        }
    }
}


//MARK: Internal Beacon types
internal protocol BeaconPayload {
    //MARK: Required
    var deviceUDID: String { get }
    var deviceName: String { get }
    var deviceType: BeaconDeviceType { get }

    //MARK: Optional
    var AWVersion: String? { get }
    var APNSToken: String? { get }
    var bundleIdentifier: String? { get }
    var deviceCompromised: Bool? { get }
    var deviceFriendlyName: String? { get }
    var deviceModel: String? { get }
    var emailAddress: String? { get }
    var locationGroup: String? { get }
    var OSVersion: String? { get }
    var phoneNumber: String? { get }
    var transactionIdentifier: String? { get }

    var WiFiMACAddress: String? { get }
    var WiFiIpAddress: String? { get }

    var gpsInfo: (latitude: CLLocationDegrees?,
                  longitude: CLLocationDegrees?,
                  altitude: CLLocationDistance?,
                  speed: CLLocationSpeed?) { get }
    var locationSampleDate: Date? { get }

    var compliancePolicies: [(policyIdentifier: String, complianceStatus: Int)]? { get }
}


///TODO: Support OSX
internal extension BeaconPayload {
    var deviceName: String {
        return UIDevice.current.name
    }

    var deviceType: BeaconDeviceType {
        return .beaconDeviceIOS
    }

    var AWVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var APNSToken: String? {
        return nil
    }

    var bundleIdentifier: String? {
        return Bundle.main.bundleIdentifier
    }

    var deviceCompromised: Bool? {
#if (arch(i386) || arch(x86_64)) && os(iOS)
        /// Simulator
        return false
#else
        return awIsCompromised()
#endif
    }

    var deviceFriendlyName: String? {
        return self.deviceName
    }

    var deviceModel: String? {
        return UIDevice.current.model
    }

    var emailAddress: String? {
        return nil
    }

    var locationGroup: String? {
        return nil
    }

    var OSVersion: String? {
        return UIDevice.current.systemVersion
    }

    var phoneNumber: String? {
        return nil
    }

    var transactionIdentifier: String? {
        return String(format: "%f1.0", Date().timeIntervalSince1970)
    }

    var WiFiMACAddress: String? {
        if let networkAdapters = UIDevice.current.aw_networkAdapters() as? [AWNetworkAdapter] {
            let en0 = networkAdapters.filter {
                (adapter: AWNetworkAdapter) -> Bool in
                return adapter.name == "en0"
            }
            return en0.count > 0 ? en0[0].macAddress?.replacingOccurrences(of:":", with: "") : nil
        } else {
            return nil
        }
    }

    var WiFiIpAddress: String? {
        if let networkAdapters = UIDevice.current.aw_networkAdapters() as? [AWNetworkAdapter] {
            let en0 = networkAdapters.filter {
                (adapter: AWNetworkAdapter) -> Bool in
                return adapter.name == "en0"
            }
            return en0.count > 0 ? en0[0].ipV4Address : nil
        } else {
            return nil
        }
    }

    var gpsInfo: (latitude: CLLocationDegrees?,
                  longitude: CLLocationDegrees?,
                  altitude: CLLocationDistance?,
                  speed: CLLocationSpeed?) {
        return(latitude: nil, longitude: nil, altitude: nil, speed: nil)
    }

    var locationSampleDate: Date? {
        return nil
    }

    var compliancePolicies: [(policyIdentifier: String, complianceStatus: Int)]? {
        return nil
    }
}


internal extension BeaconPayload {
    func JSONData() throws -> Data {
        var payloadInfo = [String: AnyObject]()
        
        /// Required
        payloadInfo[kBeaconPayloadDeviceIdentifier] = self.deviceUDID as AnyObject?
        payloadInfo[kBeaconPayloadDeviceName] = self.deviceName as AnyObject?
        payloadInfo[kBeaconPayloadDeviceType] = "\(self.deviceType.rawValue)" as AnyObject?
        
        /// Optional
        payloadInfo[kBeaconPayloadAWVersion] = self.AWVersion as AnyObject?
        payloadInfo[kBeaconPayloadAPNSToken] = self.APNSToken as AnyObject?
        payloadInfo[kBeaconPayloadBundleIdentifier] = self.bundleIdentifier as AnyObject?
        payloadInfo[kBeaconPayloadDeviceFriendlyName] = self.deviceFriendlyName as AnyObject?
        payloadInfo[kBeaconPayloadDeviceModel] = self.deviceModel as AnyObject?

        if let compromised = self.deviceCompromised {
            payloadInfo[kBeaconPayloadIsDeviceCompromised] = compromised ? "1" as AnyObject?
 : "0" as AnyObject?
        } else {
            ///XXX: When compromization detection is not available
            payloadInfo[kBeaconPayloadIsDeviceCompromised] = "0" as AnyObject?
        }

        payloadInfo[kBeaconPayloadEmailAddress] = self.emailAddress as AnyObject?
        payloadInfo[kBeaconPayloadLocationGroup] = self.locationGroup as AnyObject?
        payloadInfo[kBeaconPayloadDeviceOSVersion] = self.OSVersion as AnyObject?

        payloadInfo[kBeaconPayloadDeviceMACAddress] = self.WiFiMACAddress as AnyObject?
        payloadInfo[kBeaconPayloadDeviceIpAddress] = self.WiFiIpAddress as AnyObject?

        payloadInfo[kBeaconPayloadPhoneNumber] = self.phoneNumber as AnyObject?
        payloadInfo[kBeaconPayloadTransactionIdentifier] = self.transactionIdentifier as AnyObject?

        payloadInfo[kBeaconPayloadLatitude] = self.gpsInfo.latitude as AnyObject?
        payloadInfo[kBeaconPayloadLongitude] = self.gpsInfo.longitude as AnyObject?
        payloadInfo[kBeaconPayloadAltitude] = self.gpsInfo.altitude as AnyObject?
        payloadInfo[kBeaconPayloadSpeed] = self.gpsInfo.speed as AnyObject?
        payloadInfo[kBeaconPayloadSampleTime] = self.locationSampleDate?.description as AnyObject?

        if let policies = self.compliancePolicies {
            var compliances = [[String: AnyObject]]()
            for (pid, status) in policies {
                var dict = [String: AnyObject]()
                dict[kBeaconPayloadComplianceStatus] = status as AnyObject?
                dict[kBeaconPayloadCompliancePolicyID] = pid as AnyObject?
                compliances.append(dict)
            }
            payloadInfo[kBeaconPayloadComplianceData] = compliances as AnyObject?
        }

        if let data = self.deviceUDID.data(using: String.Encoding.utf8)?.sha256 {
            let sampleString = awBytesFromData(data)
            payloadInfo[kBeaconPayloadSample] = sampleString as AnyObject?
        }

        var payload = [String: AnyObject]()
        payload[kBeaconPayload] = payloadInfo as AnyObject?

        return try JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions(rawValue: 0))
    }
}


internal enum BeaconDeviceType: Int {
    case beaconDeviceIOS = 2
    case beaconDeviceOSX = 10
}


internal enum BeaconPayloadType: BeaconPayload {
    case ping(deviceUDID: String)
    case generalInfo(deviceUDID: String, APNToken: String?, locationGroup: String?, transID: String?)
    case userInfo(deviceUDID: String, email: String?, phone: String?)
    case GPSInfo(deviceUDID: String,
                 latitude: CLLocationDegrees?,
                 longitude: CLLocationDegrees?,
                 altitude: CLLocationDegrees?,
                 speed: CLLocationSpeed?,
                 locationSampleDate: Date?)
    case CompliancePolicies(deviceUDID: String, policies: [(policyIdentifier: String, complianceStatus: Int)]?)

    indirect case combination(deviceUDID: String,
                              general: BeaconPayloadType?,
                              user: BeaconPayloadType?,
                              gps: BeaconPayloadType?,
                              compliancePolicies: BeaconPayloadType?)

    var deviceUDID: String {
        switch self {
        case let .ping(udid):
            return udid
        case let .generalInfo(udid, _, _, _):
            return udid
        case let .userInfo(udid, _, _):
            return udid
        case let .GPSInfo(udid, _, _, _, _, _):
            return udid
        case let .CompliancePolicies(udid, _):
            return udid
        case let .combination(udid, _, _, _, _):
            return udid
        }
    }

    var APNSToken: String? {
        switch self {
        case let .generalInfo(_, token, _, _):
            return token
        case let .combination(_, general, _, _, _):
            return general?.APNSToken
        default:
            return nil
        }
    }

    var emailAddress: String? {
        switch self {
        case let .userInfo(_, email, _):
            return email
        case let .combination(_, _, user, _, _):
            return user?.emailAddress
        default:
            return nil
        }
    }

    var locationGroup: String? {
        switch self {
        case let .generalInfo(_, _, locationGroup, _):
            return locationGroup
        case let .combination(_, general, _, _, _):
            return general?.locationGroup
        default:
            return nil
        }
    }

    var phoneNumber: String? {
        switch self {
        case let .userInfo(_, _, phone):
            return phone
        case let .combination(_, _, user, _, _):
            return user?.phoneNumber
        default:
            return nil
        }
    }

    var transactionIdentifier: String? {
        switch self {
        case let .generalInfo(_, _, _, transID):
            return transID
        case let .combination(_, general, _, _, _):
            return general?.transactionIdentifier
        default:
            return String(format: "%f1.0", Date().timeIntervalSince1970)
        }
    }

    var gpsInfo: (latitude: CLLocationDegrees?,
        longitude: CLLocationDegrees?,
        altitude: CLLocationDistance?,
        speed: CLLocationSpeed?) {
        switch self {
        case let .GPSInfo(_, lat, longt, alt, speed, _):
            return (latitude: lat, longitude: longt, altitude: alt, speed: speed)
        case let .combination(_, _, _, gps, _):
            return gps?.gpsInfo ?? (latitude: nil, longitude: nil, altitude: nil, speed: nil)
        default:
            return (latitude: nil, longitude: nil, altitude: nil, speed: nil)
        }
    }

    var locationSampleDate: Date? {
        switch self {
        case let .GPSInfo(_, _, _, _, _, sampleDate):
            return sampleDate
        case let .combination(_, _, _, gps, _):
            return gps?.locationSampleDate
        default:
            return nil
        }
    }

    var compliancePolicies: [(policyIdentifier: String, complianceStatus: Int)]? {
        switch self {
        case let .CompliancePolicies(_, policies):
            return policies
        case let .combination(_, _, _, _, policies):
            return policies?.compliancePolicies
        default:
            return nil
        }
    }
}


public typealias BeaconTransmissionCompletion = (_ data: CTLJSONObject?, _ error: NSError?) -> Void

internal class SendBeaconEndpoint: DeviceServicesEndpoint {
    let kSendBeaconEndpoint = "/deviceservices/AirWatchBeacon.svc/checkin"

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = kSendBeaconEndpoint
    }

    func sendBeaconPayload(_ payload: BeaconPayload, completionHandler: @escaping BeaconTransmissionCompletion) -> Void {
        guard self.endpointURL != nil else {
            completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL("\(hostUrlString), \(serviceEndpoint)").error)
            return
        }

        do {
            let jsonPayload = try payload.JSONData()

            _ = self.fetchURL(endpointURL!,
                          dataToPost: jsonPayload,
                          ETag: nil,
                          httpMethod: "POST",
                          mayAuthorize: true,
                          executingQuery: nil) {
                            (rsp: CTLJSONObject?, error: NSError?) in
                            completionHandler(rsp, error)
            }
        } catch let err as NSError {
            completionHandler(nil, err)
        }
    }


    override internal func requestForURL(_ url: URL,
                                         ETag: String?,
                                         httpMethod: String,
                                         additionalHeaders: [String:String]?) -> NSMutableURLRequest? {
        let request = super.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: additionalHeaders)
        request?.requestType = "beacon"
        return request
    }
}
