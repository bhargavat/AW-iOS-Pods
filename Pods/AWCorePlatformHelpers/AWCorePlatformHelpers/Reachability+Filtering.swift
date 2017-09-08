//
//  Reachability.swift
//  AWCorePlatformHelpers
//
//  Created by Kishore Sajja on 12/28/16.
//  Copyright © 2016 Kishore Sajja. All rights reserved.
//

import Foundation
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import CoreTelephony

@objc(AWNetworkActivityStatus)
public enum NetworkActivityStatus: Int {
    @objc(AWNetworkActivityInit)                case unknown    /// Initial/unknown state
    @objc(AWNetworkActivityNormal)              case normal     /// Normal
    @objc(AWNetworkActivityNetworkNotReachable) case networkNotReachable /// When Either there is no network (no wifi or cellular) or in airplane mode.
    @objc(AWNetworkActivityBadSSID)             case connectedToUnknownSSID /// SSID does not match what is listed
    @objc(AWNetworkActivityCellularDisabled)    case cellularDataConnectionDisabled /// Celluar data is completely disabled
    @objc(AWNetworkActivityRoaming)             case cellularDataConnectionDisabledWhileRoaming  /// Celluar data is disabled while roaming
    @objc(AWNetworkActivityProxyFailed)         case proxySetupFailed /// Proxy setup failed.
}

@objc(AWNetworkAccessAllowCellular)
public enum AllowCellularNetworkAccess: Int {
    case never = 0
    case always = 1
    case notRoaming = 2
}

@objc(AWNetworkAccessAllowWiFi)
public enum AllowWiFiNetworkAccess: Int {
    case always = 1
    case filter = 2
}


public extension Reachability {
    
    internal static var connectedSSID: String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }
        for interface in interfaces {
            let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any]
            if let ssid = networkInfo?[kCNNetworkInfoKeySSID as String] as? String{
                return ssid
            }
        }
        return nil
    }
    
    fileprivate static var carrierISOCountryCode: String? {
        let network = CTTelephonyNetworkInfo()
        return network.subscriberCellularProvider?.isoCountryCode;
    }
    
    public func getDeviceRoamingStatus(completion: @escaping (_ isRoaming: Bool, _ error: Error?) -> Void) {
        DispatchQueue.main.async {
            let status:CLAuthorizationStatus = CLLocationManager.authorizationStatus()
            if  status == .authorizedWhenInUse ||
                status == .authorizedAlways {
                AWLogError("Device Roaming could not be evaluated as the location permission is not granted");
                completion(false, nil)
                return
            }
            
            guard
                let carrierCountryCode = Reachability.carrierISOCountryCode
                else {
                    AWLogError("Device Roaming could not be evaluated as the carrier country code is missing ");
                    completion(false, nil)
                    return
            }
            
            guard
                let lastKnownLocation = CLLocationManager().location
                else {
                    AWLogError("Device Roaming could not be evaluated as the lastKnownLocation is missing ");
                    completion(false, nil)
                    return
            }
            
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(lastKnownLocation) { (placemarks, error) in
                guard error == nil else {
                    AWLogError("Reverse Geocoding failed: \(String(describing: error))")
                    completion(false, error)
                    return
                }
                
                guard
                    let currentCountry = placemarks?.first?.isoCountryCode,
                    currentCountry.caseInsensitiveCompare(carrierCountryCode) == .orderedSame
                    else {
                        AWLogInfo("\(carrierCountryCode) Device is found to be roaming in \(placemarks?.first?.isoCountryCode ?? "<no conuntry code found>")");
                        completion(true, nil)
                        return
                }
                AWLogInfo("Device is not roaming");
                completion(false, nil)
            }
        }
    }
    
    public func evaluateConnectedNetworkActivityStatus(allowedSSIDS: [String],
                                                       cellularAccess: AllowCellularNetworkAccess,
                                                       completion: @escaping (_ status:NetworkActivityStatus, _ error: Error?) -> Void) {
        let networkStatus = Reachability.forInternetConnection?.currentReachabilityStatus ?? .notReachable
        switch (networkStatus, cellularAccess) {
        case (.notReachable, _):
            completion(.networkNotReachable, nil)
            
        case (.reachableViaWifi, _):
            guard
                allowedSSIDS.count != 0,
                allowedSSIDS.contains("") == false,
                allowedSSIDS.contains("*") == false
                else{
                    completion(.normal, nil)
                    break
            }
            
            guard
                let connectedSSID = Reachability.connectedSSID,
                allowedSSIDS.contains(connectedSSID)
                else {
                    completion(.connectedToUnknownSSID, nil)
                    break
            }
            
            completion(.normal, nil)
            
        case (.reachableViaWWAN, .never):
            completion(.cellularDataConnectionDisabled, nil)
            
        case (.reachableViaWWAN, .notRoaming):
            self.getDeviceRoamingStatus{ (isRoaming, error) in
                if isRoaming {
                    completion(.cellularDataConnectionDisabledWhileRoaming, nil)
                } else {
                    completion(.normal, error)
                }
            }
            
        case (_, _):
            completion(.normal, nil)
        }
    }
}
