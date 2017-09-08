//
//  EnrollmentInformation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit

extension CoderKeys {
    class EnrollmentInformation {
        static let hostname = "hostname"
        static let deviceIdentifier = "deviceIdentifier"
        static let organizationGroup = "organizationGroup"
        static let lastVerifiedDate = "lastVerifiedDate"
        static let lastKnownStatus = "lastKnownStatus"
    }
}

public class EnrollmentInformation: NSObject, NSCoding {
    open var hostname: String?
    open var deviceIdentifier: String?
    open var organizationGroup: String?
    open var lastVerifiedDate: Date?
    open var lastKnownEnrollmentStatus = AWSDK.EnrollmentStatus.unknown

    /* ISDK-169306 check the root cause in the description
     * Do not rely on stored enrollment status as Agent does not clear
     * this value on fresh enrollment (this is new entry in keychain starting 17.x)
     * A stale value could be present in the keychain
     switch lastKnownEnrollmentStatus {
     case .deviceNotFound, .unenrolled:
     break
     default:
     return isComplete
     }*/
    open var isComplete: Bool {

        guard let hostname = self.hostname,
            let deviceId = self.deviceIdentifier else {
                return false
        }

        if hostname.isEmpty || deviceId.isEmpty {
            return false
        }

        return true
    }

    @objc required convenience public init(coder decoder: NSCoder) {
        self.init()
        self.hostname = decoder.decodeObject(forKey: CoderKeys.EnrollmentInformation.hostname) as? String
        self.deviceIdentifier = decoder.decodeObject(forKey: CoderKeys.EnrollmentInformation.deviceIdentifier) as? String
        self.organizationGroup = decoder.decodeObject(forKey: CoderKeys.EnrollmentInformation.organizationGroup) as? String
        self.lastVerifiedDate = decoder.decodeObject(forKey: CoderKeys.EnrollmentInformation.lastVerifiedDate) as? Date
        let enrollmentStatus = decoder.decodeCInt(forKey: CoderKeys.EnrollmentInformation.lastKnownStatus)
        self.lastKnownEnrollmentStatus = AWSDK.EnrollmentStatus(rawValue: Int(enrollmentStatus)) ?? AWSDK.EnrollmentStatus.unknown
    }

    @objc open func encode(with coder: NSCoder) {
        if let hostname = hostname {
            coder.encode(hostname, forKey: CoderKeys.EnrollmentInformation.hostname)
        }

        if let deviceIdentifier = deviceIdentifier {
            coder.encode(deviceIdentifier, forKey: CoderKeys.EnrollmentInformation.deviceIdentifier)
        }

        if let organizationGroup = organizationGroup {
            coder.encode(organizationGroup, forKey: CoderKeys.EnrollmentInformation.organizationGroup)
        }

        if let lastVerifiedDate = lastVerifiedDate {
            coder.encode(lastVerifiedDate, forKey: CoderKeys.EnrollmentInformation.lastVerifiedDate)
        }
        
        coder.encodeCInt(Int32(self.lastKnownEnrollmentStatus.rawValue), forKey: CoderKeys.EnrollmentInformation.lastKnownStatus)
    }
}


extension EnrollmentInformation {
    open override func isEqual(_ object: Any?) -> Bool {
        if self === object as AnyObject? { return true }

        if let other = object as? EnrollmentInformation {
            return (self.hostname == other.hostname &&
                self.deviceIdentifier == other.deviceIdentifier &&
                self.organizationGroup == other.organizationGroup &&
                self.lastKnownEnrollmentStatus == other.lastKnownEnrollmentStatus )
        }

        return false
    }
}
