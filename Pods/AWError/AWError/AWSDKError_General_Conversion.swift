//
//  AWSDKError_General_DataConversion.swift
//  AWError
//
//  Created by "Liu, Troy" on 11/14/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.General.Conversion {
    enum ToData: AWSDKErrorType {
        
    }
    
    enum FromData: AWSDKErrorType {
        case inputDataNil
        case inputDataZeroLength
        case inputFileNil
        case inputFileReadFailed
        case stringSerializationFailed
        case jsonSerializationFailed
        case propertyListSerializationFailed
    }
}


