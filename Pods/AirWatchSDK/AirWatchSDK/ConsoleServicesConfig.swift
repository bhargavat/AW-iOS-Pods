//
//  ConsoleServicesConfig.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWServices

final class ConsoleServicesConfig: UserAuthConfig, DeviceServicesConfiguration, EnrollmentServicesConfig {
    var airWatchServerURL: String
    var organizationGroup: String
    var deviceId: String
    var deviceType = "\(UIDevice.current.deviceTypeIdentifier)"
    var bundleId: String
    var requestingApp: String
    var authenticationGroup: String

    init?(enrollmentInfo: EnrollmentInformation) {
        guard let hostname = enrollmentInfo.hostname,
            let deviceIdentifier = enrollmentInfo.deviceIdentifier,
            let organizationGroup = enrollmentInfo.organizationGroup,
            let bundleIdentifier = Bundle.main.bundleIdentifier else {
                return nil;
        }

        self.deviceId = deviceIdentifier
        self.airWatchServerURL = hostname
        self.organizationGroup = organizationGroup
        self.bundleId = bundleIdentifier
        self.requestingApp = bundleIdentifier
        self.authenticationGroup = bundleIdentifier
    }

    convenience init?(identity: Identity) {
        if let enrollment = identity.enrollment {
            self.init(enrollmentInfo: enrollment)
        } else {
            return nil
        }
    }

    func getEnrollmentInformation() -> EnrollmentInformation {
        let enrollmentInfo = EnrollmentInformation()
        enrollmentInfo.hostname = self.airWatchServerURL
        enrollmentInfo.organizationGroup = self.organizationGroup
        enrollmentInfo.deviceIdentifier = self.deviceId
        return enrollmentInfo
    }
}
