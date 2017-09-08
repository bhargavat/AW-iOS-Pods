
//
//  AWLocationService.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CoreLocation

@objc
public enum AWLocationMode : Int {
    case disabled = -1
    case standard
    case significant
    case regionMonitoring
}

let DEFAULT_DISTANCE_FILTER = 500.0
let DEFAULT_RADIUS = 1000.0
let NO_OF_CONCENTRIC_REGIONS = 5

public let AWLocationServiceDidReceiveDeviceLocationNotification = "AWLocationServiceDidReceiveDeviceLocationNotification"
let AWLocationServiceOldLocationKey = "AWLocationServiceOldLocationKey"
let AWLocationServiceNewLocationKey = "AWLocationServiceNewLocationKey"
let AWLocationServiceSelfRegionMonitor = "AWLocationServiceSelfRegionMonitor"
let AWLocationServiceMonitoredRegionKey = "AWLocationServiceMonitoredRegionKey"
let AWLocationServiceEnterExitRegionFlagKey = "LocationServiceEnterExitRegionFlagKey"
let AWLocationServiceDidEnterExitRegionKey = "AWLocationServiceDidEnterExitRegionKey"
let AWLocationServiceRegionMonitoringFailedKey = "AWLocationServiceRegionMonitoringFailedKey"
let AWLocationServiceRegionMonitoringFailedErrorKey = "AWLocationServiceRegionMonitoringFailedErrorKey"

let AWLocationServiceIBeaconMonitor = "AWLocationServiceIBeaconMonitor"
let AWLocationServiceIBeaconDidEnterExitRegionKey = "AWLocationServiceIBeaconDidEnterExitRegionKey"
let AWLocationServiceEnterExitIBeaconFlagKey = "AWLocationServiceEnterExitIBeaconFlagKey"
let AWLocationServiceMonitoredIBeaconKey = "AWLocationServiceMonitoredIBeaconKey"

internal protocol AWNotificationCenterProtocol {
    
}
extension AWNotificationCenterProtocol {
    func post(name aName: NSNotification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable : Any]?) {
        NotificationCenter.default.post(name: aName, object: anObject, userInfo: aUserInfo)
    }
}

internal struct AWNotificationCenter: AWNotificationCenterProtocol {
}

public final class AWLocationService : NSObject, CLLocationManagerDelegate {
    public static let sharedInstance : AWLocationService = AWLocationService()
    
    fileprivate var locationManager : CLLocationManager?
    
    public fileprivate (set) var currentLocationMode : AWLocationMode = .disabled
    
    // internal backing variable
    fileprivate var _locationDistanceFilter : CLLocationDistance = DEFAULT_DISTANCE_FILTER
    // publicly available variable to set with checks
    public var locationDistanceFilter : CLLocationDistance {
        get {
            return _locationDistanceFilter
        }
        set {
            if newValue > 0 {
                _locationDistanceFilter = newValue
            } else {
                _locationDistanceFilter = DEFAULT_DISTANCE_FILTER
            }
        }
    }

    
    fileprivate var _desiredAccuracy : CLLocationAccuracy = 0.0
    public var desiredAccuracy : CLLocationAccuracy {
        get {
            return _desiredAccuracy
        } set {
            _desiredAccuracy = newValue
            locationManager?.desiredAccuracy = _desiredAccuracy
        }
    }
    
    public var currentLocation : CLLocation?
    public var currentRadius : CLLocationDistance?
    public var region : CLRegion?

    internal var notificationCenter: AWNotificationCenterProtocol = AWNotificationCenter()
    
    override init() {
        super.init()
        self.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    public func startUpdatingLocation() {
        if self.currentLocationMode == .standard {
            //Service is Running on Standard, think about what to do
        } else if self.currentLocationMode == .significant {
            self.stopUpdatingSignificantLocation()
        }
        
        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            self.locationManager!.delegate = self
            self.locationManager!.desiredAccuracy = self.desiredAccuracy
            self.locationManager!.requestAlwaysAuthorization()
        }

        self.currentLocationMode = .standard
        self.locationManager!.distanceFilter = self.locationDistanceFilter
        self.locationManager!.startUpdatingLocation()
        
        #if TARGET_OS_IPHONE
        self.locationManager!.pausesLocationUpdatesAutomatically = false
        #endif
    }
    
    public func stopUpdatingLocation() {
        if self.currentLocationMode == .standard {
            if self.locationManager != nil {
                self.locationManager!.stopUpdatingLocation()
            }
            
            self.currentLocationMode = .disabled
            self.locationManager = nil
        }
    }
    
    public func startUpdatingSignificantLocation() {
        if self.currentLocationMode == .standard {
            //Service is Running on Standard, think about what to do
        } else if self.currentLocationMode == .significant {
            self.stopUpdatingSignificantLocation()
        }
    
        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            self.locationManager!.delegate = self
            self.locationManager!.requestAlwaysAuthorization()
        }

        
        self.currentLocationMode = .significant
        self.locationManager!.startMonitoringSignificantLocationChanges()
    }
    
    public func stopUpdatingSignificantLocation() {
        if self.currentLocationMode == .significant {
            if self.locationManager != nil {
                self.locationManager!.stopMonitoringSignificantLocationChanges()
            }
            
            self.currentLocationMode = .disabled
            self.locationManager = nil
        }
    }
    
    public func startRegionMonitoring() {

        NSLog("AWlocation started Region Monitoring")
        
        if self.currentLocationMode == .regionMonitoring && self.region != nil && self.region!.identifier.range(of: AWLocationServiceSelfRegionMonitor) != nil{
            self.currentLocation = self.locationManager?.location!
            self.currentRadius = DEFAULT_RADIUS
            self.region = CLCircularRegion.init(center: self.currentLocation!.coordinate, radius: self.currentRadius!, identifier: AWLocationServiceSelfRegionMonitor)
        }

        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            self.locationManager!.delegate = self
            self.locationManager!.requestAlwaysAuthorization()
            
            if self.currentRadius == nil {
                self.currentRadius = DEFAULT_RADIUS
            }
            
            if self.region == nil {
                self.currentLocation = self.locationManager!.location
                self.region = CLCircularRegion.init(center: self.currentLocation!.coordinate, radius: self.currentRadius!, identifier: AWLocationServiceSelfRegionMonitor)
            }
            
            if self.desiredAccuracy == 0 {
                self.desiredAccuracy = kCLLocationAccuracyBest
            }
        }
        
        if self.currentLocation == nil {
            self.currentLocation = self.locationManager!.location
        }
        
        if self.region != nil {
            self.currentLocationMode = .regionMonitoring
            self.setMonitoringRegions()
        }
    }
    
    public func stopRegionMonitoring() {
        if  self.region != nil {
            self.locationManager!.stopMonitoring(for: self.region!)
        }
        self.region = nil
        self.currentRadius = 0
    }

    fileprivate func setMonitoringRegions(){
        self.locationManager!.startMonitoring(for: self.region!)
        NSLog("%s", self.locationManager!.monitoredRegions)
        if self.region! is CLBeaconRegion {
            return
        }
        
        NSLog("Monitoring %s", self.region!.identifier)
        if self.region!.identifier == AWLocationServiceSelfRegionMonitor {
            var count = 1
            var concentricRegion : CLCircularRegion?
            var previousRad = 3 * self.currentRadius!
            let circularRegion : CLCircularRegion = self.region! as! CLCircularRegion
            
            while count < NO_OF_CONCENTRIC_REGIONS {
                concentricRegion = CLCircularRegion.init(center: circularRegion.center, radius: previousRad, identifier: AWLocationServiceSelfRegionMonitor + String(count))
                previousRad = previousRad * 2
                count += 1
                self.locationManager!.startMonitoring(for: concentricRegion!)
                concentricRegion = nil
            }
        } else {
            self.locationManager!.requestState(for: self.region!)
            self.locationManager!.startMonitoring(for: self.region!)
        }
    }
    

    //MARK: Location Manager Delegate
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        NSLog("======> New location to update <=====")
        
        let newLocation = locations.last!
        NSLog("Recieved GPS coords {%f, %f}", newLocation.coordinate.latitude, newLocation.coordinate.longitude )
        
        let userInfo : [ String : CLLocation ] = [ AWLocationServiceNewLocationKey : newLocation ]
        self.currentLocation = newLocation
        
        notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidReceiveDeviceLocationNotification), object: nil, userInfo: userInfo)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AWLogError( "AWLocation failed with error: \(error)")
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            
            let info : [ String : AnyObject ] = [ AWLocationServiceEnterExitIBeaconFlagKey : Int(1) as AnyObject,
                AWLocationServiceMonitoredIBeaconKey : beaconRegion ]
            
            AWLogInfo("Entered the ibeacon region with id \(beaconRegion.identifier) and uuid \(beaconRegion.proximityUUID)")
            notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceIBeaconDidEnterExitRegionKey), object: nil, userInfo: info)
            
        } else {
            
            var userInfo : [String : AnyObject] = [AWLocationServiceMonitoredRegionKey : region]
            if let newLocation = manager.location {
                userInfo[AWLocationServiceNewLocationKey] = newLocation
            }
            
            let circularRegion : CLCircularRegion = region as! CLCircularRegion
            NSLog("Entered the region with region id %@ and radius %f", region.identifier, circularRegion.radius)
            
            var compareString : String = region.identifier
            compareString = compareString.trimmingCharacters(in: CharacterSet(charactersIn: "12345"))
            
            if compareString == AWLocationServiceSelfRegionMonitor {
                if self.currentLocation != nil && self.currentLocation!.coordinate.latitude == circularRegion.center.latitude && self.currentLocation!.coordinate.longitude == circularRegion.center.longitude {
                    
                    notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidReceiveDeviceLocationNotification), object: nil, userInfo: userInfo)
                    
                    self.currentLocation = manager.location
                    self.region = CLCircularRegion.init(center: circularRegion.center, radius: self.currentRadius!, identifier: AWLocationServiceSelfRegionMonitor)
                    self.setMonitoringRegions()
                }
            } else {
                let info : [String : AnyObject] = [AWLocationServiceEnterExitRegionFlagKey : Int(1) as AnyObject,
                                                       AWLocationServiceMonitoredRegionKey : region]
                
                notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidEnterExitRegionKey), object: nil, userInfo: info)
                notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidReceiveDeviceLocationNotification), object: nil, userInfo: userInfo)
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion{
            let info : [ String : AnyObject ] = [ AWLocationServiceEnterExitIBeaconFlagKey : Int(2) as AnyObject,
                                                  AWLocationServiceMonitoredIBeaconKey : beaconRegion ]
            
            AWLogInfo("Exited from the ibeacon region with id region.identifier and uuid \(beaconRegion.proximityUUID)")
            notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceIBeaconDidEnterExitRegionKey), object: nil, userInfo: info)
            
        } else {
            var userInfo : [String : AnyObject] = [AWLocationServiceMonitoredRegionKey : region]
            if let newLocation = manager.location {
                userInfo[AWLocationServiceNewLocationKey] = newLocation
            }
            
            let circularRegion : CLCircularRegion = region as! CLCircularRegion
            NSLog("Exited the region with region id %@ and radius %f", region.identifier, circularRegion.radius)
            
            var compareString : String = region.identifier
            compareString = compareString.trimmingCharacters(in: CharacterSet(charactersIn: "12345"))
            
            if compareString == AWLocationServiceSelfRegionMonitor {
                if self.currentLocation != nil && self.currentLocation!.coordinate.latitude == circularRegion.center.latitude && self.currentLocation!.coordinate.longitude == circularRegion.center.longitude {
                    notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidReceiveDeviceLocationNotification), object: nil, userInfo: userInfo)
                    self.currentLocation = manager.location
                    self.region = CLCircularRegion.init(center: circularRegion.center, radius: self.currentRadius!, identifier: AWLocationServiceSelfRegionMonitor)
                    self.setMonitoringRegions()
                }
            } else {
                let info : [String : AnyObject] = [AWLocationServiceEnterExitRegionFlagKey : Int(2) as AnyObject,
                                                   AWLocationServiceMonitoredRegionKey : region]
                
                notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidEnterExitRegionKey), object: nil, userInfo: info)
                notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidReceiveDeviceLocationNotification), object: nil, userInfo: userInfo)
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        NSLog("Region monitoring failed with error: %@", error.localizedDescription)
        let userInfo : [String : AnyObject] = [AWLocationServiceRegionMonitoringFailedErrorKey : error as AnyObject,
                                               AWLocationServiceMonitoredRegionKey : region!]
        notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceRegionMonitoringFailedKey), object: nil, userInfo: userInfo)
    }
    
    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            AWLogInfo("Determined state for iBeacon region with id \(beaconRegion.identifier) and uuid \(beaconRegion.proximityUUID)")
            let userInfo : [String : AnyObject] = [AWLocationServiceEnterExitIBeaconFlagKey : {()->Int in if state == CLRegionState.inside { return 1 } else { return 2 }}() as AnyObject,
                                                   AWLocationServiceMonitoredRegionKey : region ]
            notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceIBeaconDidEnterExitRegionKey), object: nil, userInfo: userInfo)
        } else {
            var userInfo : [String : AnyObject] = [AWLocationServiceMonitoredRegionKey : region]

            if let newLocation = manager.location {
                userInfo[AWLocationServiceNewLocationKey] = newLocation
            }
            
            let info : [String : AnyObject] = [AWLocationServiceEnterExitRegionFlagKey : {()->Int in if state == CLRegionState.inside { return 1 } else { return 2 }}() as AnyObject,
                                               AWLocationServiceMonitoredRegionKey : region]
            
            notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidEnterExitRegionKey), object: nil, userInfo: info)
            notificationCenter.post(name: Notification.Name(rawValue: AWLocationServiceDidReceiveDeviceLocationNotification), object: nil, userInfo: userInfo)
        }
    }
}

