//
//  AWSDKError_Controller.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


public extension AWError.SDK {
    enum Controller: AWSDKErrorType {
        case enrollmentServicesNotProperlySet
        case deviceServicesNotProperlySet
    }
}

public extension AWError.SDK.Controller {
    var localizableInfo: String? {
        switch self {
        case .enrollmentServicesNotProperlySet:
            return "Enrollment Services is not set properly."
        case .deviceServicesNotProperlySet:
            return "Device Services is not set properly."
        }
    }
}
