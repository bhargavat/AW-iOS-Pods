//
//  CustomErrorConvertible.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


public protocol CustomErrorConvertible {
    func userInfo() -> Dictionary<String, String>?
    func errorDomain() -> String
    func errorCode() -> Int
}


extension CustomErrorConvertible {
    public func asNSError() -> NSError {
        return NSError(domain: self.errorDomain(), code: self.errorCode(), userInfo: self.userInfo())
    }
}
