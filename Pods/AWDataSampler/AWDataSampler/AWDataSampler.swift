//
//  AWDataSampler.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


// For Obj-C usage
@objc
open class AWDataSampler: NSObject, DataSamplerDelegate {

    // Singleton for Obj-C usage
    open static let mDataSamplerModule = AWDataSampler()
    
    open var transmitAtStartUp = false

    open var g_AWDataSamplerIsStarted: Bool {
        return dataSamplerStarted
    }
    
    open var sendGPSImmediate: Bool {
        get {
            return dataSampler.sendGPSDataOnDemand
        }
        set {
            dataSampler.sendGPSDataOnDemand = newValue
        }
    }
    
    // Beacuse of design change, AWDataSampler is always initialized with a Default Configuration
    open fileprivate(set) var g_AWDataSamplerIsInitialized = true
    
    // Beacuse of design change, AWDataSampler is transmitting over HTTP
    open fileprivate(set) var transmitType = AWDataSamplerTransmitterType.http
    
    
    
    var dataSamplerConfiguration: DataSamplerConfiguration
    var dataSampler: DataSampler
    var dataSamplerStarted: Bool
    
    var delegate: AWDataSamplerTransmitterDelegate?
    var completionHandler: ((_ err: NSError?) -> Void)?
    
    override init() {
        dataSamplerConfiguration = DataSamplerConfiguration.default
        dataSampler = DataSampler(config: dataSamplerConfiguration)
        dataSamplerStarted = false
        super.init()
        dataSampler.delegate = self
    }
    
    @objc
    open func setConfig(_ config: AWDataSamplerConfiguration) {
        if dataSamplerStarted {
            // stop the old data sampler
            dataSampler.stop()
        }
        dataSamplerConfiguration = config.toDataSamplerConfiguration()
        dataSampler = DataSampler(config: dataSamplerConfiguration)
        dataSamplerStarted = false
        dataSampler.delegate = self
    }
    
    // outError is quietly ignored, the error will make its way back to the delegate
    @objc
    open func startUp(_ outError: NSErrorPointer) -> Bool {
        if !dataSamplerStarted {
            dataSamplerStarted = true
            dataSampler.start(transmitAtStartUp)
        } else {
            // Should probably return a false, but doesn't occur in original method
        }
        return true
    }
    
    // outError is quietly ignored, the error will make its way back to the delegate
    @objc
    open func shutDown(_ outError: NSErrorPointer) -> Bool {
        guard dataSamplerStarted else {
            return false
        }
        dataSamplerStarted = false
        // stop the data sampler
        dataSampler.stop()
        return true
    }
    
    // outError is quietly ignored, the error will make its way back to the delegate
    @objc
    open func Transmit(_ outError: NSErrorPointer, delegate: AWDataSamplerTransmitterDelegate?) {
        self.delegate = delegate
        dataSampler.transmitImmediately()
    }
    
    // outError is quietly ignored, the error will make its way back to the completionHandler
    @objc
    open func Transmit(_ outError: NSErrorPointer, withCompletionHandler completionHandler: ((_ err: NSError?) -> Void)?) {
        self.completionHandler = completionHandler
        dataSampler.transmitImmediately()
    }

    @objc
    open func SampleModules() {
        dataSampler.sampleImmediately()
    }
    
    // outError is quietly ignored, the error will make its way back to the completionHandler
    @objc
    open func TransmitCellular(_ outError: NSErrorPointer, withCompletionHandler completionHandler: ((_ err: NSError?) -> Void)?) {
        Transmit(outError, withCompletionHandler: completionHandler)
    }
    
    // delegate methods of DataSampler
    open func DataSamplerSamplingErrorNotify(_ sampler: DataSampler, error: NSError) {
        log(error: "While Data Sampler was sampling, recieved an error: \(error).")
    }
    open func DataSamplerDidSendSamples(_ sampler: DataSampler) {
        delegate?.DataMessageSendSucessfully(nil, transmitter: nil)
        completionHandler?(nil)
    }
    open func DataSamplerFailedSendingSamples(_ sampler: DataSampler, error: NSError) {
        self.delegate?.DataMessageSendFailed(nil, error: error, transmitter: nil)
        completionHandler?(error)
    }
    
}

@objc
open class AWDataSamplerConfiguration: NSObject {
    var sampleModule: AWDataSamplerModules
    var sampleInterval: TimeInterval
    var transmitInterval: TimeInterval
    var traceLevel: AWTraceLevel
    
    @objc(initWithSampleModules:defaultSampleInterval:defaultTransmitInterval:traceLevel:)
    public init(sampleModules bitmask: AWDataSamplerModuleBitmask,
         defaultSampleInterval: TimeInterval,
         defaultTransmitInterval: TimeInterval,
         traceLevel: AWTraceLevel) {
        sampleModule = AWDataSamplerConfiguration.bitmaskToSampleModules(bitmask)
        sampleInterval = defaultSampleInterval
        transmitInterval = defaultTransmitInterval
        self.traceLevel = traceLevel
        
        super.init()
    }
    
    // Create a Swift equivalent of self
    internal func toDataSamplerConfiguration() -> DataSamplerConfiguration {
        return .custom(sampleInterval: sampleInterval,
                       transmitInterval: transmitInterval,
                       urlScheme: "http",
                       traceLevel: traceLevel,
                       sampleModules: sampleModule)
    }
    
    
    // Convert the bitmask into the Swift equivalent
    internal static func bitmaskToSampleModules(_ bitmask: AWDataSamplerModuleBitmask) -> AWDataSamplerModules {
        return AWDataSamplerModules(rawValue: bitmask.rawValue)
    }
}

@objc
public protocol AWDataSamplerTransmitterDelegate: class {
    func DataMessageSendSucessfully(_ payload: AWDataPayload?, transmitter: NSObject?)
    func DataMessageSendFailed(_ payload: AWDataPayload?, error: NSError, transmitter: NSObject?)
}


// Not actually used, only for sake of AWDataSamplerTransmitterDelegate protocol
@objc
open class AWDataPayload: NSObject {
    var sampleData: NSMutableData?
    
    @objc(initWithData:)
    public init(data: Data) {
        sampleData = (data as NSData).mutableCopy() as? NSMutableData
    }
    
    open func addSample(_ sample: AWDataSample) {
        if let data = sample.data() {
            sampleData?.append(data)
        }
    }
    
    
}

// Not actually used, only for sake of AWDataSamplerTransmitterDelegate protocol
@objc
open class AWDataSample: NSObject {
    
    func data() -> Data? {
        return nil
    }
}
