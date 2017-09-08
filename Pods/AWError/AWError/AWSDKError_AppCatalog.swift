//
//  AWSDKError_AppCatalog.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum AppCatalog: AWSDKErrorType {
        case iconDownloadMalformedURL
        case iconDownloadUnableFetchData
    }
}

public extension AWError.SDK.AppCatalog {
    var code: Int {
        // The code start from 1 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWAppCatalogErrors.h
        return _code + 1
    }
    
    var errorDescription: String {
        switch self {
        case .iconDownloadMalformedURL:
            return "The request could not be fulfilled because of a malformed Application Icon URL."
        case .iconDownloadUnableFetchData:
            return "Unable to download application icon data."
        }
    }
}
