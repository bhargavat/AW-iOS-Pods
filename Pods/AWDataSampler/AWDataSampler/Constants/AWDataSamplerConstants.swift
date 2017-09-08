//
//  DataSamplerConstants.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import Foundation
    
/**
 \enum DataSamplerType
 \brief An enum stating various types of Data Samplers. Possible sample values are :
 \details AWDataSamplerModuleNone = Default value.\n
 AWDataSamplerModuleSystem = System module of DataSampler. \n
 AWDataSamplerModuleAnalytics = Analytics module of DataSampler. \n
 AWDataSamplerModuleGPS = GPS module of DataSampler. \n
 AWDataSamplerModuleNetworkData = NetworkData module of DataSampler. \n
 AWDataSamplerModuleCallLog = Call log module of DataSampler. \n
 AWDataSamplerModuleNetworkAdapter = Network adapter module of DataSampler. \n
 AWDataSamplerModuleWLAN2Sample = WLAN2 sample module of DataSampler. \n
 AWDataSamplerModuleAppSample = Application sample module of DataSampler.
*/

@objc public enum DataSamplerType : UInt
{
    case none            = 0
    case system          = 0b1
    case analytics       = 0b10
    case gps             = 0b100
    case networkData     = 0b1000
    case callLog         = 0b10000
    case networkAdapter  = 0b100000
    case wlan2Sample     = 0b1000000
    case appSample       = 0b10000000
}

/** \enum AWAnalyticsEvent
 \brief : An enum stating various Analytics Event. Possible sample values are : \n
 AWAnalyticsCustomEvent : Signals a custom event has occured. \n
 AWAnalyticsSessionStarted : Signals the start of an AWAnalytics Session \n
 AWAnalyticsSessionEnded : Signals the end of an AWAnalytics Session \n
 AWAnalyticsViewDidAppear : Signals that a view appeared \n
 AWAnalyticsViewDidDisappear : Signals that a view has disappeared \n
 */

@objc(AWDataSamplerAnalyticsEvent)
public enum AnalyticsEvent: UInt16, SwiftEnumSerializable
{
    case customEvent = 0
    case sessionStarted
    case sessionEnded
    case viewDidAppear
    case viewDidDisappear

    public func data() throws -> Data {
        return self.dataFromInteger(self.rawValue)
    }
}

/**
 \enum  AWAnaltyicsEventValueType
 \brief Valid event values. \n
 AWAnalyticsValueNone : Use when there is no value associated with an event. \n
 AWAnalyticsValueInteger : Use when the value associated with an event is an integer. \n
 AWAnalyticsValueLong : Use when the value associated with an event is a long. \n
 AWAnalyticsValueString : Use when the value associated with an event is a long. \n
 */
@objc public enum AWAnalyticsEventValueType : UInt16, SwiftEnumSerializable
{
    case none = 0
    case integer
    case long
    case string

    public func data() throws -> Data {
        return self.dataFromInteger(self.rawValue)
    }
}

/**
 \enum  AWDataSampleType
 \brief Different data sample types.
*/

public enum AWDataSampleType : UInt16{
    case none               = 0
    case gps                = 10
    case cellularData       = 18
    case systemPower        = 20
    case memory             = 21
    case systemInformation  = 22
    case networkAdapter     = 40
    case dataUsage          = 80
    case analytics          = 112
}

/**
 \enum  AWTraceLevel
 \brief Various Trace Levels. Possible values are :\n
 AWTraceLevelOff : Output no tracing and debugging messages.\n
 AWTraceLevelError : Output error-handling messages.\n
 AWTraceLevelWarning : Output warnings and error-handling messages.\n
 AWTraceLevelInfo : Output informational messages, warnings, and error-handling messages.\n
 AWTraceLevelVerbose : Output all debugging and tracing messages.\n
 */
// TODO: check with what AWLogLevel ends up being
@objc public enum AWTraceLevel : UInt16
{
    case off		= 0
    case error		= 1
    case warning	= 2
    case info		= 3
    case verbose	= 4
}

/** \brief DataSamplerFlag status type */

@objc public enum DataSamplerFlag : UInt16
{
    case none               = 0
    case dataResponse       = 6
    case ready              = 16
    case error              = 64
    case readyResponse      = 80
    case data               = 128
};


/** \enum AWDataSamplerTransmitterType
 \brief An enum holding the possible DataSampler transmission types. Possible values are :\n
 kTransmitterUnknown : Transmit method unknown.\n
 kTransmitterHttp : Transmit Interrogator samples through HTTP.\n
 kTransmitterTcp : Transmit Interrogator samples through TCP. \n
 */

@objc public enum AWDataSamplerTransmitterType : UInt16
{
    case unknown = 0
    case http
    case tcp
}

/** \brief System file sent through beacon. */
let systemFileName                       = "System.dat"

/** \brief Analytics file sent through beacon. */
let analyticsFileName                    = "Analytics.dat"

 /** \brief Network adapters file sent through interrogator. */
let networkAdapterFileName               = "NetworkAdapters.dat"

/** \brief GPS data file. */
let gpsFileName                          = "GPS.dat"

/** \brief GPS file sent through beacon. */
let gpsBeaconFileName                    = "BeaconGps.dat"

/** \brief GPS should be sent through beacon. */
let beaconShouldSendGPS                  = "BeaconShouldSendGPS"

/** \brief WLAN2Sample2 be sent through interrogator. **/
let wlan2Sample                          = "WLAN2Sample.dat"

/** \brief application sample sent through interrogator. **/
let applicationSample                    = "application.dat"

/** \brief Platform type to be used in ReadyMessagePayload */
let platFormTypeiOS                          = 2    //for PlatformiOS
