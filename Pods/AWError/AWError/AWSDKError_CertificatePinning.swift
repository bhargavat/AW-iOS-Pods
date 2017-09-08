//
//  AWSDKError_CertificatePinning.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum CertificatePinning: AWSDKErrorType {
        case malformedURL
        case certificateFetchInProgress
        case autodiscoverEndpointAlreadyCalledOnceInFGStateOfApp
        case dsEndpointCanNotProceedSinceAutodiscoveryReturnNULL
        case certificateNotAvailableForHost
        case credentialNotAvialableForHost
        case authenticationMethodNotSupported
        case certificateShareNotSupported
        case invalidCertificateRequested
        case failedToFetchPinningCertificate
    }
}

public extension AWError.SDK.CertificatePinning {
    var errorDescription: String {
        switch self {
        case .malformedURL:
            return "The request could not be fulfilled because of a malformed URL."
        case .autodiscoverEndpointAlreadyCalledOnceInFGStateOfApp:
            return "We need to call AW autodiscovery endpoint only once, even if it does not return payload"
        default:
            return String(describing: self)
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .failedToFetchPinningCertificate:
            return "AutodiscoveryPublicKeyAuthenticationFailureMessage"
        default:
            return nil
        }
    }
}
