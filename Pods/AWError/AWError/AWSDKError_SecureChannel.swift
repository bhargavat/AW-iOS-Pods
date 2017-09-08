//
//  AWSDKError_SecureChannel.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


/* following is the SecureChannel from old SDK(5.9)
 *
public extension AWError.SDK {
    enum SecureChannel: AWSDKErrorType {
        case InvalidServerCertificate
        case HandshakeFailed
    }
}

public extension AWError.SDK.SecureChannel {
    var errorDescription: String {
        switch self {
        case .InvalidServerCertificate: return "The server certificate returned is not trusted."
        case .HandshakeFailed:          return "The handshake process was not completed successfully."
        }
    }
}
 
 *
 */

public extension AWError.SDK {
    enum SecureChannel: AWSDKErrorType {
        
    }
}