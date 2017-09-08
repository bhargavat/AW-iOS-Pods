//
//  Enums.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWServices

extension AWSDK.AuthenticationMethod: DataRepresentable {

    public func toData() -> Data? {
        return self.rawValue.toData()
    }

    public static func fromData(_ data: Data?) -> AWSDK.AuthenticationMethod? {
        if let authMethod = Int.fromData(data) {
            return AWSDK.AuthenticationMethod(rawValue: authMethod)
        }
        return nil
    }
}

extension AWSDK.BiometricMethod: DataRepresentable {

    public func toData() -> Data? {
        return self.rawValue.toData()
    }

    public static func fromData(_ data: Data?) -> AWSDK.BiometricMethod? {
        guard let biometricMethodData = data else { return nil }
        if let authMethod = Int.fromData(biometricMethodData) {
            return AWSDK.BiometricMethod(rawValue: authMethod)
        }
        return AWSDK.BiometricMethod.none
    }

}
