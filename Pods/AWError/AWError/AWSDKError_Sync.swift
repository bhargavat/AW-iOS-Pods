//
//  AWSDKError_Sync.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Sync: AWSDKErrorType {
        case general
        case empty
        case inconsistentState
        case ssoPinEmpty
    }
}

public extension AWError.SDK.Sync {
    var code: Int {
        // The code start from 41000 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWSDKErrors_Private.h
        return _code + 41000
    }
    
    var localizableInfo: String? {
        switch self {
        case .general:
            return "SyncResponseError"
        case .empty:
            return "SyncResponseEmpty"
        case .inconsistentState:
            return "SyncResponseInconsistentState"
        case .ssoPinEmpty:
            return "SyncResponseEmptyPin"
        }
    }
    
    var errorDescription: String {
        switch self {
        case .general:
            return "Error in sync response"
        case .empty:
            return "Sync response is empty"
        case .inconsistentState:
            return "Set up could not be done. Error in state"
        case .ssoPinEmpty:
            return "Pin value in response is empty"
        }
    }
    
}
