//
//  Sampler.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import AWHelpers
import AWError
import Foundation

internal enum DataSamplerFile: String {
    case analytics      = "Analytics.dat"
    case application    = "application.dat"
    case dataUsage      = "DataUsage.dat"
    case gps            = "GPS.dat"
    case networkAdapter = "NetworkAdapters.dat"
    case systemInfo     = "System.dat"
    case wlan2          = "WLAN2Sample.dat"
}

@objc
open class DataSampler: NSObject {
    private var modules: [DataSamplerModule] = []

    private let config: AWDataSamplerConfigurationProtocol

    private var sampleFiles:[DataSampleType: DataSampleFileHandle] = [
            .systemInformation: DataSampleFileHandle(file: .systemInfo),
            .systemPower: DataSampleFileHandle(file: .systemInfo),
            .systemMemory: DataSampleFileHandle(file: .systemInfo),
            .analytics:  DataSampleFileHandle(file: .analytics),
            .gps: DataSampleFileHandle(file: .gps),
            .dataUsage: DataSampleFileHandle(file: .dataUsage),
            .networkAdapterInformation: DataSampleFileHandle(file: .networkAdapter) ]

    
    private var deviceServices: DeviceServices? = nil

    private let transmitQueue: DispatchQueue = DispatchQueue(label: "com.vmware.AWDataSampler.DataSampler.transmission", attributes: [])

    private var shouldStopDataCollectionAndTransmission = false

    open var delegate: DataSamplerDelegate? = nil
    open var sendGPSDataOnDemand: Bool = false

    // Covenience inits beacuse objective-c cannot handle default parameters
    public convenience override init() {
        self.init(config: DataSamplerConfiguration.default, deviceServices: nil)
    }
    
    public convenience init(config: AWDataSamplerConfigurationProtocol) {
        self.init(config: config, deviceServices: nil)
    }
    
    public convenience init(deviceServices: DeviceServices) {
        self.init(config: DataSamplerConfiguration.default, deviceServices: deviceServices)
    }
    
    public init(config: AWDataSamplerConfigurationProtocol, deviceServices: DeviceServices?) {
        self.config = config
        self.modules = config.sampleModules.modules
        self.deviceServices = deviceServices
        super.init()
        //TODO: start & stop calllog collector
        /// Register GPS location update
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(receivedGPSUpdate(_:)),
                                               name: NSNotification.Name(AWLocationServiceDidReceiveDeviceLocationNotification),
                                               object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self,
                                                name: NSNotification.Name( AWLocationServiceDidReceiveDeviceLocationNotification),
                                                object: nil)
    }

    @objc
    open func start(_ transmit: Bool = false) {
        modules.forEach { (module) in
            module.startSampling(self.config.defaultSampleInterval) { (samples: [DataSample], error: NSError?) in
                if let e = error {
                    log(error: "Data Sampling Error: \(e.localizedDescription)")
                    if let samplerDelegate = self.delegate {
                        self.ON_MAIN {
                            samplerDelegate.DataSamplerSamplingErrorNotify(self, error: e)
                        }
                    }
                    return
                }
                self.saveSamples(samples)
            }
        }
        self.collectDataSampleAndTransmit(shouldRepeat: true, sendOneImmediately: transmit)
    }

    @objc
    open func stop() {
        modules.forEach { $0.stopSampling() }
        self.shouldStopDataCollectionAndTransmission = true
    }

    open func sampleImmediately() {
        for module in modules {
            do {
                let samples  = try module.sample()
                saveSamples(samples)
            } catch let err as NSError {
                log(error: "Data Sampling Error: \(err)")
                if let samplerDelegate = self.delegate {
                    ON_MAIN {
                        samplerDelegate.DataSamplerSamplingErrorNotify(self, error: err)
                    }
                }
            }

        }
    }

    open func transmitImmediately() {
        self.collectDataSampleAndTransmit(shouldRepeat: false, sendOneImmediately: true)
    }

    open func addSample(_ sample: DataSample) {
        if let fileHandle = sampleFiles[sample.sampleType] {
            fileHandle.write(samples: [sample])
        }
    }

    open func purgeSamples(_ modules: AWDataSamplerModules) {
        if modules.contains(.system) {
            sampleFiles[.systemInformation]?.purge()
        }
        
        if self.config.sampleModules.contains(.analytics) {
            sampleFiles[.analytics]?.purge()
        }
        
        if !self.sendGPSDataOnDemand && self.config.sampleModules.contains(.gps) {
            sampleFiles[.gps]?.purge()
        }
        
        if self.config.sampleModules.contains(.networkData) {
            sampleFiles[.dataUsage]?.purge()
        }
        
        if self.config.sampleModules.contains(.networkAdapter) {
            sampleFiles[.networkAdapterInformation]?.purge()
        }
    }

    private func ON_MAIN(_ block: () -> Void) {
        if Thread.current == Thread.main {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }

    fileprivate func saveSamples(_ samples: [DataSample]) {
        var sampleGroups = [DataSampleType: [DataSample]]()
        for sample in samples {
            if sampleGroups[sample.sampleType] == nil {
                sampleGroups[sample.sampleType] = [DataSample]()
            }
            sampleGroups[sample.sampleType]?.append(sample)
        }

        for (sampleType, sampleGroup) in sampleGroups {
            let fileHandle = sampleFiles[sampleType]
            fileHandle?.write(samples: sampleGroup)
        }
    }

    //MARK: transmission

    private func transmitSamples(data samplesData: Data) {
        let sampler = self
        guard let deviceServices = self.deviceServices else {
            log(error: "Device Services are not configured. Can not start trasmission of Samples")
            return
        }
        
        /// Always start new message sending sequence (with updated token)
        deviceServices.sendDataSamplerReadyPacket { (packet: DataSamplerPacket?, error: NSError?) in
            guard error == nil else {
                if let error = error {
                    log(error: "Error on transmitting data sampler ready packet: \(error.localizedDescription)")
                    sampler.ON_MAIN {
                        sampler.delegate?.DataSamplerFailedSendingSamples(sampler, error: error)
                    }
                }
                return
            }

            guard let packet = packet else {
                log(error: "Unexpected response on transmitting data sampler ready packet")
                self.ON_MAIN {
                    let error = AWError.SDK.DataSampler.internalDataTransmissionError.error
                    sampler.delegate?.DataSamplerFailedSendingSamples(sampler, error: error)
                }
                return
            }
            
            deviceServices.sendDataSamplerDataPacket(packet.token, data: samplesData) {
                (packet: DataSamplerPacket?, error: NSError?) in
                guard error == nil else {
                    if let error = error {
                        log(error: "Error on transmitting data sampler data packet: \(error.localizedDescription)")
                        sampler.ON_MAIN {
                            sampler.delegate?.DataSamplerFailedSendingSamples(sampler, error: error)
                        }
                    }
                    return
                }

                sampler.ON_MAIN {
                    log(debug: "Data sampler packet sent successfully but no callback as delegate is not set")
                    sampler.delegate?.DataSamplerDidSendSamples(sampler)
                }
                
                /// Remove all files
                sampler.purgeSamples(.all)
            }
        }
    }

    private func collectSamplesData() -> Data {
        /// Data collecting has to follow strict order
        var payloadData = Data()
        let generatePayload = { (type: DataSampleType) in
            guard let fileHandle = self.sampleFiles[type] else {
                log(error: "Could not retrieve \(type) sample for transmision")
                return
            }
            
            payloadData.append(fileHandle.readToData())
        }

        //generatePayload(.DataSampleTypeApplication)
        generatePayload(.systemInformation)
        generatePayload(.systemPower)
        generatePayload(.systemMemory)
        generatePayload(.analytics)
        generatePayload(.networkAdapterInformation)
        //generatePayload(.DataSampleTypeWLAN2)

        if !sendGPSDataOnDemand {
            generatePayload(.gps)
        }

#if os(iOS)
        generatePayload(.dataUsage)
        ///TODO: call data
#endif
        return payloadData
    }

    private func collectDataSampleAndTransmit(shouldRepeat: Bool, sendOneImmediately: Bool = false) {

        if sendOneImmediately {
            self.transmitQueue.async {
                let samplesData = self.collectSamplesData()
                self.transmitSamples(data: samplesData)
            }
        }
        
        guard shouldRepeat && self.shouldStopDataCollectionAndTransmission == false else {
            return
        }

        let after = DispatchTime.now() + self.config.transmitInterval
        self.transmitQueue.asyncAfter(deadline: after) { [weak self] in
            self?.collectDataSampleAndTransmit(shouldRepeat: true, sendOneImmediately: true)
        }
    }

    private func transmitGPSSamples() {
        guard let fileHandle = self.sampleFiles[.gps] else {
            log(error: "Could not retrieve GPS sample for transmision")
            return
        }
        var payloadData = Data()
        payloadData.append(fileHandle.readToData())
        transmitSamples(data: payloadData)
    }

    //MARK: GPS
    @objc
    fileprivate func receivedGPSUpdate(_ notification: Notification?) {
        // Call notifications are received with location services enabled with a default distance filter
        // So need not check call log at each GPS update
        let locationMode = AWLocationService.sharedInstance.currentLocationMode

        if self.config.sampleModules.contains(.gps) {
            do {
                let module = DataSamplerGPSModule()
                let samples  = try module.sample()
                saveSamples(samples)
            } catch let err as NSError {
                log(error: "GPS Data Sampling Error: \(err)")
                if let samplerDelegate = self.delegate {
                    ON_MAIN {
                        samplerDelegate.DataSamplerSamplingErrorNotify(self, error: err)
                    }
                }
            }

            if sendGPSDataOnDemand {
                transmitGPSSamples()
            }

            if case locationMode = AWLocationMode.significant {
                sampleImmediately()
                transmitImmediately()
            }
        }

        if case locationMode = AWLocationMode.regionMonitoring {
            sampleImmediately()
            transmitImmediately()
        }
    }

}
