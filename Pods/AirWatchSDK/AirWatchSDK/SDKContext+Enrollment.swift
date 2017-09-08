//
//  SDKContext.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWServices
import AWStorage
import AWHelpers

protocol EnrollmentInformationProvider {
    var enrollmentInformation: EnrollmentInformation? { get set }
}

extension SDKServerDetailsControllerDatasource where Self: EnrollmentInformationProvider {

    mutating func createEnrollmentInformation(_ url: String, orgGroup: String) -> EnrollmentInformation? {
        let enrollment = self.enrollmentInformation ?? EnrollmentInformation()
        enrollment.hostname = url
        enrollment.organizationGroup = orgGroup

        if enrollment.deviceIdentifier == nil {
            #if arch(i386) || arch(x86_64)
                enrollment.deviceIdentifier = SDKDefaultSettings.sharedSettings.mockedSimulatorUDID()
            #else
                //generate device UDID
                guard let uuidData = UIDevice.current.identifierForVendor?.uuidString.data(using: String.Encoding.utf8), let generatedUDID = uuidData.sha1 else {
                    return nil
                }
                enrollment.deviceIdentifier = generatedUDID.hexadecimalString
            #endif
        }
        return enrollment
    }
}
