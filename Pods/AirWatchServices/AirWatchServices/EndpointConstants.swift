//
//  EndpointConstants.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
    Beacon Constants
 */
/// Required Keys
public let kBeaconPayload = "payLoad"
public let kBeaconPayloadDeviceIdentifier = "DeviceIdentifier"
public let kBeaconPayloadDeviceName = "Name"
public let kBeaconPayloadDeviceType = "DeviceType"
public let kBeaconPayloadAPNSToken = "APNSToken"
public let kBeaconPayloadIsDeviceCompromised = "IsCompromised"

/// Optional Keys
public let kBeaconPayloadAWVersion = "AWVersion"
public let kBeaconPayloadBundleIdentifier = "BundleId"
public let kBeaconPayloadDeviceOSVersion = "OsVersion"
public let kBeaconPayloadDeviceModel = "Model"
public let kBeaconPayloadLocationGroup = "CustomerLocationGroupRef"
public let kBeaconPayloadDeviceFriendlyName = "FriendlyName"
public let kBeaconPayloadDeviceMACAddress = "MacAddress"
public let kBeaconPayloadEmailAddress = "EmailAddress"
public let kBeaconPayloadPhoneNumber = "PhoneNumber"
public let kBeaconPayloadTransactionIdentifier = "TransactionIdentifier"
public let kBeaconPayloadDeviceIpAddress = "IpAddress"
public let kBeaconPayloadComplianceData = "ComplianceData"
public let kBeaconPayloadComplianceStatus = "Status"
public let kBeaconPayloadCompliancePolicyID = "PolicyIdentifier"
public let kBeaconPayloadSample = "SampleValue"

/// GPS Keys
public let kBeaconPayloadLatitude = "Latitude"
public let kBeaconPayloadLongitude = "Longitude"
public let kBeaconPayloadAltitude = "Altitude"
public let kBeaconPayloadSpeed = "Speed"
public let kBeaconPayloadSampleTime = "SampleTime"
