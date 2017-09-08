//
//  Configuration.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWHelpers

/**
    Compatible APIs
 */

public protocol AWDataSamplerConfigurationProtocol {
    var defaultSampleInterval: TimeInterval { get }
    var transmitInterval: TimeInterval { get }
    var urlScheme: String { get }
    var sampleModules: AWDataSamplerModules { get }
    
    init(sampleModules: AWDataSamplerModules, defaultSampleInterval: TimeInterval, defaultTransmitInterval: TimeInterval, traceLevel: AWTraceLevel)
}

public struct AWDataSamplerModules: OptionSet {
    public  let rawValue : UInt
    public  init(rawValue:UInt) { self.rawValue = rawValue }
    
    public static let system = AWDataSamplerModules(rawValue: 1 << 0)
    public static let analytics = AWDataSamplerModules(rawValue: 1 << 1)
    public static let gps = AWDataSamplerModules(rawValue: 1 << 2)
    public static let networkData = AWDataSamplerModules(rawValue: 1 << 3)
    public static let callLog = AWDataSamplerModules(rawValue: 1 << 4)
    public static let networkAdapter = AWDataSamplerModules(rawValue: 1 << 5)
    public static let wlan2Sample = AWDataSamplerModules(rawValue: 1 << 6)
    public static let appSample = AWDataSamplerModules(rawValue: 1 << 7)
    public static let all = AWDataSamplerModules(rawValue: 0xFF)
}

public enum DataSamplerConfiguration {
    case `default`
    case all
    case disabled
    case filtered(moduleFilter: (_ module: AWDataSamplerModules) -> Bool)
    case custom(sampleInterval: TimeInterval, transmitInterval: TimeInterval, urlScheme: String, traceLevel: AWTraceLevel, sampleModules: AWDataSamplerModules)
}

extension DataSamplerConfiguration: AWDataSamplerConfigurationProtocol {
    
    public var defaultSampleInterval: TimeInterval {
        if case .custom(let sampleInterval, _, _, _, _) = self {
            return sampleInterval
        }
        return 5.0 * 60
    }

    public var transmitInterval: TimeInterval {
        if case .custom(_, let transmitInterval, _, _, _) = self {
            return transmitInterval
        }
        return 5.0 * 60
    }

    public var urlScheme: String {
        if case .custom(_, _, let urlScheme, _, _) = self {
            return urlScheme
        }
        return "http"
    }
    
    private static let allModules:[AWDataSamplerModules] = [.system, .analytics, .gps, .networkData, .callLog, .networkAdapter, .wlan2Sample, .appSample]
    
    public var sampleModules: AWDataSamplerModules {
        switch self {
        case .default:
            return .system
            
        case .all:
            return .all
            
        case let .filtered(sampleFilter):
            let modules = DataSamplerConfiguration.allModules.filter(sampleFilter)
            var filtered: AWDataSamplerModules = []
            modules.forEach { filtered.insert($0) }
            return filtered
        
        case .disabled:
            return []
            
        case let .custom(_, _, _, _, sampleModules):
            return sampleModules
        }
    }
    
    public init(sampleModules: AWDataSamplerModules, defaultSampleInterval: TimeInterval, defaultTransmitInterval: TimeInterval, traceLevel: AWTraceLevel) {
        self = .custom(sampleInterval: defaultSampleInterval,
                       transmitInterval: defaultTransmitInterval,
                       urlScheme: "http",
                       traceLevel: traceLevel,
                       sampleModules: sampleModules)
    }
}

extension AWDataSamplerModules {
    
    var modules: [DataSamplerModule] {
        
        var modules: [DataSamplerModule] = []
        
        if self.contains(.system) {
            modules.append(DataSamplerSystemModule())
        }
        
        if self.contains(.analytics) {
            modules.append(DataSamplerAnalyticsModule())
        }
        
        if self.contains(.gps) {
            modules.append(DataSamplerGPSModule())
        }
        
        if self.contains(.networkData) {
            modules.append(DataSamplerDataUsageModule())
        }
        
        if self.contains(.networkAdapter),
            let allAdapters = UIDevice().aw_networkAdapters() as? [AWNetworkAdapter] {
            allAdapters.forEach { modules.append(DataSamplerNetworkAdapterModule(inAdapter: $0)) }
        }
        //TODO: CallLog module
        return modules
    }
}
