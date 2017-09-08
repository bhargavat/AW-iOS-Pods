//
//  CoderKeys.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWStorage


class CoderKeys { }

extension AWSDK.EnrollmentStatus: DataRepresentable {
    public func toData() -> Data? {
        return self.rawValue.toData()
    }
    public static func fromData(_ data: Data?) -> AWSDK.EnrollmentStatus? {
        if let value: Int = Int.fromData(data),
        let status = AWSDK.EnrollmentStatus(rawValue: value) {
            return status
        }
        return nil
    }
}
