//
//  DataSamplerGPSModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers

class DataSamplerGPSModule: DataSamplerBaseModule {
    override func sample() throws -> [DataSample]
    {
        let locationService = AWLocationService.sharedInstance
        
        guard let currLocation = locationService.currentLocation else{
            log(error: "Unable to get current location while sampling for GPS")
            return [DataSample]()
        }
        
        let latitude = currLocation.coordinate.latitude
        let longitude = currLocation.coordinate.longitude
        let speed = Float32(currLocation.speed)
        let heading = Float32(currLocation.course)
        let altitude = Float32(currLocation.altitude)
        
        let gpsSample = DataSampleGPS.init(latitude: latitude, longitude: longitude, speed: speed, heading: heading, altitude: altitude)
        
        var sample = [DataSample]()
        sample.append(gpsSample)
        return sample
    }
}
