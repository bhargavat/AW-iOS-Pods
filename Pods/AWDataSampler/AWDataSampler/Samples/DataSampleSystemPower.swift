//
//  DataSamplePower.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWHelpers


public struct DataSampleSystemPower: DataSample {
    var base: BaseDataSample

    let powerLineStatus: AWDevicePowerLineType
    let batteryStatus: UInt8
    let batteryLifePercent: AWDeviceBatteryLevel
    let batteryLifeTime: UInt32
    let batteryFullLifeTime: UInt32

    let backupBatteryStatus: AWDeviceBatteryStatus
    let backupBatteryLifePercent: AWDeviceBatteryLevel
    let backupBatteryLifeTime: UInt32
    let backupBatteryFullLifeTime: UInt32

    let batteryVoltage: UInt32
    let batteryCurrent: UInt32

    let batteryAverageCurrent: UInt32
    let batteryAverageInterval: UInt32

    let batteryDischarge: UInt32
    let batteryTemperature: Float32
    let backupBatteryVoltage: UInt32
    let batteryChemistry: AWDeviceBatteryChemistry

    public var sampleType: DataSampleType {
        return .systemPower
    }

    public init(powerLineStatus: AWDevicePowerLineType = .unknown,
                batteryStatus: UInt8 = 0,
                batteryLifePercent: AWDeviceBatteryLevel = 0,
                batteryLifeTime: UInt32 = 0,
                batteryFullLifeTime: UInt32 = 0,
                backupBatteryStatus: AWDeviceBatteryStatus = .unknown,
                backupBatteryLifePercent: AWDeviceBatteryLevel = 0,
                backupBatteryLifeTime: UInt32 = 0,
                backupBatteryFullLifeTime: UInt32 = 0,
                batteryVoltage: UInt32 = 0,
                batteryCurrent: UInt32 = 0,
                batteryAverageCurrent: UInt32 = 0,
                batteryAverageInterval: UInt32 = 0,
                batteryDischarge: UInt32 = 0,
                batteryTemperature: Float32 = 0,
                backupBatteryVoltage: UInt32 = 0,
                batteryChemistry: AWDeviceBatteryChemistry = .unknown) {

        base = BaseDataSample(type: .systemPower)

        self.powerLineStatus = powerLineStatus
        self.batteryStatus = batteryStatus
        self.batteryLifePercent = batteryLifePercent
        self.batteryLifeTime = batteryLifeTime
        self.batteryFullLifeTime = batteryFullLifeTime

        self.backupBatteryStatus = backupBatteryStatus
        self.backupBatteryLifePercent = backupBatteryLifePercent
        self.backupBatteryLifeTime = backupBatteryLifeTime
        self.backupBatteryFullLifeTime = backupBatteryFullLifeTime

        self.batteryVoltage = batteryVoltage
        self.batteryCurrent = batteryCurrent

        self.batteryAverageCurrent = batteryAverageCurrent
        self.batteryAverageInterval = batteryAverageInterval

        self.batteryDischarge = batteryDischarge
        self.batteryTemperature = batteryTemperature
        self.backupBatteryVoltage = backupBatteryVoltage
        self.batteryChemistry = batteryChemistry

        if let data = try? self.data() {
            self.base.messageSize = UInt16(data.count)
        } else {
            self.base.messageSize = 0
        }
    }
}
