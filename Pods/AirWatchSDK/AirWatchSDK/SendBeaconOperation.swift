//
//  SendBeaconOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import CoreLocation
import AWHelpers

internal class SendBeaconOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        log(info: "Will Send Beacon.")
        self.StartSendingDeviceStatusBeacon()
        self.markOperationComplete()
    }
    
    private func StartSendingDeviceStatusBeacon() {
        let defaultSettings = SDKDefaultSettings.sharedSettings
        var transmitInterval = TimeInterval(defaultSettings.heartBeatInterval())
        if transmitInterval <= 0 {
            transmitInterval = TimeInterval(4 * 60 * 60)
        }

        SDKBeaconTransmitter.sharedTransmitter.startSendingDeviceStatusBeacon(transmitFrequency: transmitInterval)
    }

}
