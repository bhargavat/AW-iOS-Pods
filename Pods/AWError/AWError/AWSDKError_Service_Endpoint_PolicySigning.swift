//
//  AWSDKError_Service_Endpoint_PolicySigning.swift
//  AWError
//
//  Created by "Liu, Troy" on 9/2/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Service.Endpoint {
    enum PolicySigning: AWSDKErrorType {
        case general
        case failedToFetchCertificate
        case failedToDecodeCertificateData(GivenEncoding: String?)
        case failedToCreateCertificate(GivenType: String?)
    }
}
