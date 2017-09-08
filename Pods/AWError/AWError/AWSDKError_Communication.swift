//
//  AWSDKError_Communication.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum Communication: AWSDKErrorType {
        case general
        case failedToEstablishSession
        case failedToRegister
        case failedToFetchPin
        case failedToRenewHMAC
        case failedToRenewSession
        case deviceNotEnrolled
        case failedToCreatePasscode
        case failedToChangePasscode
        case deviceIdentifierEmpty
        case authenticationCancelled
        case azaAccessTokenFetchFailed
        case failedToFetchCertificate
    }
}

public extension AWError.SDK.Communication {
    var code: Int {
        // The code start from 8100 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWSDKCommon.h
        return _code + 8100
    }
}
