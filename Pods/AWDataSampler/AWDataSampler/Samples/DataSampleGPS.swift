//
//  DataSampleGPS.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWHelpers
import Foundation


public struct DataSampleGPS: DataSample {
    var base: BaseDataSample
    let latitude: Double
    let longitude: Double
    let speed: Float32
    let heading: Float32
    let magneticVariation: Double
    let altitude: Float32
    let facility: UInt16
    let eventCode: UInt32
    let noteLength: UInt16
    let note: NSData

    public var sampleType: DataSampleType {
        return .gps
    }

    public init(latitude: Double = 0, longitude: Double = 0, speed: Float32 = 0, heading: Float32 = 0,
                magneticVariation: Double = 0, altitude: Float32 = 0, facility: UInt16 = 0,
                eventCode: UInt32 = 0, note: NSData = NSData())
    {
        base = BaseDataSample(type: .gps)

        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.heading = heading
        self.magneticVariation = magneticVariation
        self.altitude = altitude
        self.facility = facility
        self.eventCode = eventCode
        self.noteLength = UInt16(note.length)
        self.note = note.copy() as! NSData

        if let data = try? self.data() {
            self.base.messageSize = UInt16(data.count)
        } else {
            self.base.messageSize = 0
        }
    }
}
