//
//  DataSampleAnalytics.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWHelpers
import Foundation


public struct DataSampleAnalytics: DataSample {
    var base: BaseDataSample

    let nameSize: UInt16
    let valueSize: UInt16
    let bundleIDSize: UInt16
    let bundleVersionSize: UInt16
    let bundleNameSize: UInt16
    let eventType: AnalyticsEvent
    let valueType: AWAnalyticsEventValueType

    let sessionUUID: Data
    let name: Data
    let value: Data
    let bundleID: Data
    let bundleVersion: Data
    let bundleName: Data

    public var sampleType: DataSampleType {
        return .analytics
    }

    public init(eventName: Data, eventValue: Data, sessionUUID: Data, eventType: AnalyticsEvent,
                valueType: AWAnalyticsEventValueType, bundleVersion: Data, bundleName: Data, bundleID: Data) {
        self.base = BaseDataSample(type: .analytics)
        self.name = eventName
        self.nameSize = UInt16(self.name.count)
        self.value = eventValue
        self.valueSize = UInt16(self.value.count)
        ///precondition(sessionUUID.length == 36)
        self.sessionUUID = sessionUUID
        self.eventType = eventType
        self.valueType = valueType
        self.bundleVersion = bundleVersion
        self.bundleVersionSize = UInt16(self.bundleVersion.count)
        self.bundleName = bundleName
        self.bundleNameSize = UInt16(self.bundleName.count)
        self.bundleID = bundleID
        self.bundleIDSize = UInt16(self.bundleID.count)

        if let data = try? self.data() {
            self.base.messageSize = UInt16(data.count)
        } else {
            self.base.messageSize = 0
        }
    }
}
