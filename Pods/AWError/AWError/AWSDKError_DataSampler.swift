//
//  AWSDKError_DataSampler.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum DataSampler: AWSDKErrorType {
        case notInitialized
        case invalidConfiguration
        case failedTransmission
        case internalDataTransmissionError
    }
}

public extension AWError.SDK.DataSampler {
    var localizableInfo: String? {
        switch self {
        case .internalDataTransmissionError:
            return "Internal error on transmitting sample data"
        default:
            return nil
        }
    }
    
    var errorDescription: String {
        switch self {
        case .notInitialized:
            return "Data Sampler not Initialized"
        case .invalidConfiguration:
            return "DataSampler Configuration is currently nil. You must initialize the AWDataSampler with a configuration before attempting to start."
        case .failedTransmission:
            return "DataSampler failed transmission"
        case .internalDataTransmissionError:
            return String(describing: self)
        }
    }
}
