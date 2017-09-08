//
//  AWSDKError_Presenter.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Presenter: AWSDKErrorType {
        case userCanceled
        case unknown
    }
}

public extension AWError.SDK.Presenter {
    var localizableInfo: String? {
        switch self {
        case .userCanceled:
            return "User tapped cancel in SDKChangePasscodeViewController."
        case .unknown:
            return "Unknown SDKPresenterError"
        }
    }
}
