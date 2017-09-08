//
//  AWServices+EnumStringConvertible.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension AWSDK.AuthenticationMethod: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none :
            return "None"

        case .passcode:
            return "Passcode"

        case .usernamePassword:
            return "UsernamePassword"
        }
    }
}

extension AWSDK.BiometricMethod: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "None"

        case .touchID:
            return "TouchID"
        }
    }
}

extension AWSDK.PasscodeMode: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .off:
            return "Off"

        case .numeric:
            return "Numeric"

        case .alphanumeric:
            return "Alphanumeric"
        }
    }
}

extension AWSDK.EnrollmentStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .deviceNotFound:
            return "DeviceNotFound"

        case .discovered:
            return "Discovered"

        case .registered:
            return "Registered"

        case .enrollmentInProgress:
            return "EnrollmentInProgress"

        case .enrolled:
            return "Enrolled"

        case .enterpriseWipePending:
            return "EnterpriseWipePending"

        case .deviceWipePending:
            return "DeviceWipePending"

        case .retired:
            return "Retired"

        case .unenrolled:
            return "Unenrolled"

        case .unknown:
            return "Unknown"
        }   
    }
}

extension AWSDK.ProxyType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "None"

        case .mag:
            return "Mag"

        case .f5:
            return "F5"

        case .standard:
            return "Standard"
        }
    }
}
