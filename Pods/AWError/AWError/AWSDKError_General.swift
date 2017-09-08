//
//  AWSDKError_General.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum General: AWSDKErrorType {
        case fileDoesNotExist
        case unableToWriteFile
        case configurationValuesUnavailable
        case moduleNotInitialized
        case internalServerError
        case jsonSerializationError
        case unexpectedJSONType
        case jsonDeserializationFailed
        case missingParameters
        case unhandledExceptionError
    }
}

public extension AWError.SDK.General {
    enum Conversion {

    }
}

public extension AWError.SDK.General {
    var errorDescription: String {
        switch self {
        case .fileDoesNotExist:               return "The requested file does not exist."
        case .unableToWriteFile:              return "Unable to save requested file."
        case .configurationValuesUnavailable: return "The module was unable to read configuration values."
        case .moduleNotInitialized:           return "The module was not initialized."
        case .internalServerError:            return "The endpoint encountered an internal server error."
        case .jsonDeserializationFailed:      return "JSON deserialization failed."
        default:                              return String(describing: self)
        }
    }
}


