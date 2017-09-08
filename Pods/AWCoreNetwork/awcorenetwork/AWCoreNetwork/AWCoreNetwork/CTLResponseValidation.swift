//
//  CTLResponseValidation.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWCrypto

/**
    Response Validator to validate the response before we start processing.
 */
public protocol CTLResponseValidationProtocol {

    func validateResponse(_ response: HTTPURLResponse?, responseData: Data?, completion:(NSError?) -> Void) -> Void

}
