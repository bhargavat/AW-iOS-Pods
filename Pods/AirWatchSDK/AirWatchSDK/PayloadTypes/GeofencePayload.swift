//
//  GeofencePayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CoreLocation

@objc(AWGeofenceArea)
public class GeofenceArea: NSObject {

    public fileprivate(set) var center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    public fileprivate(set) var radius: CLLocationDistance = 0
    public fileprivate(set) var uniqueID: String?
    public fileprivate(set) var name: String?

    init(dictionary: [String: AnyObject]) {
        var centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()


        let latitude: Double? = dictionary[GeofencePayloadConstants.kGeofencePayloadAreaCenterX] as? Double
        let longitude: Double? = dictionary[GeofencePayloadConstants.kGeofencePayloadAreaCenterY] as? Double

        //check for a missing latitude or longitude
        if let latitude = latitude, let longitude = longitude {
            centerCoordinate.latitude = latitude
            centerCoordinate.longitude = longitude
        } else { // set to 0,0 if either one is missing
            centerCoordinate.latitude = 0
            centerCoordinate.longitude = 0
        }

        if let radius = dictionary[GeofencePayloadConstants.kGeofencePayloadAreaRadius] as? Double {
            self.radius = radius
        }

        self.center = centerCoordinate
        self.name = dictionary[GeofencePayloadConstants.kGeofencePayloadAreaName] as? String
        self.uniqueID = dictionary[GeofencePayloadConstants.kGeofencePayloadAreaID] as? String
    }
}

/**
 * @brief       Geofence payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the geofence group of an SDK profile.
 * @version     6.0
 */
@objc(AWGeofencePayload)
public class GeofencePayload: ProfilePayload {

    /** A boolean indicating if geofencing should be enabled. */
    public fileprivate (set) var isEnabled: Bool = false

    /** An array containing all geofence area values. */
    public fileprivate (set) var geofenceAreas: [GeofenceArea]

    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String : Any]) {
        self.geofenceAreas = []
        super.init(dictionary: dictionary)
        guard dictionary[GeofencePayloadConstants.kPayloadType] as? String == GeofencePayloadConstants.kGeofencePayloadType else {
            log(error: "Failed to get GeofencePayload")
            return
        }
        
        self.isEnabled ??= dictionary.bool(for: GeofencePayloadConstants.kGeofencePayloadIsEnabled)

        if let gAreas = dictionary[GeofencePayloadConstants.kGeofencePayloadAreas] as? [[String: AnyObject]] {
            self.geofenceAreas = gAreas.flatMap { GeofenceArea(dictionary: $0) }
        }
    }

    override public class func payloadType() -> String {
        return GeofencePayloadConstants.kGeofencePayloadType
    }
}
