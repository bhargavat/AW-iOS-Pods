//
//  Abstct.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

extension AbstractDataStoreItemLoader {

    fileprivate var deviceIdentifier: String? {
        get {
            if let KeychainDeviceID: String = self.commonDataStore.fetch(self.itemQueryProvider.EnrollmentDeviceUDID) {
                return KeychainDeviceID
            }

            if let managedDeviceIdentifier = SDKManagedSettings.currentSetings.deviceIdentifier {
                return managedDeviceIdentifier
            }

            if let containerEnrolledDeviceUDID: String = self.commonDataStore.fetch(self.itemQueryProvider.ContainerEnrollmentDeviceUDID) {
                return containerEnrolledDeviceUDID
            }

            return nil
        }
        set {
            if !self.commonDataStore.set(itemQueryProvider.EnrollmentDeviceUDID, value: newValue) {
                log(error: "Error Setting Device ID in Keychain")
            }
        }
    }

    // it is necessary to lower case the server url so that when this is passed to other third party network modules values are not different between SDK and other modules.
    //ISDK-169820 launching SCL app modifies the serverurl with path '/deviceservices' appended. this creates a problem
    //with securechannel if we already have setup without '/deviceservices' appeneded in the end
    fileprivate var serverURL: String? {
        get {
            if let serverURLString: String = self.commonDataStore.fetch(itemQueryProvider.ApplicationServerURL) {
                let lowercasedServerURL = serverURLString.lowercased()
                
                guard let urlString =
                    lowercasedServerURL.urlOriginString()
                    else {
                        log(error:"invalid server url stored in keychain")
                        return SDKManagedSettings.currentSetings.airwatchServerURL
                }
                return urlString
            }
            return SDKManagedSettings.currentSetings.airwatchServerURL
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.ApplicationServerURL, value: newValue)
        }
    }

    fileprivate var organizationGroup: String? {
        get {
            if let locationGroupData: String = self.commonDataStore.fetch(itemQueryProvider.LocationGroup) {
                return locationGroupData
            }

            return SDKManagedSettings.currentSetings.locationGroup
        }
        set {
            _ = self.self.commonDataStore.set(itemQueryProvider.LocationGroup, value: newValue)
        }
    }

    fileprivate var enrollmentVerificationDate: Date? {
        get {
            return self.commonDataStore.fetch(itemQueryProvider.EnrollmentVerificationDate)
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.EnrollmentVerificationDate, value: newValue)
        }
    }

    fileprivate var enrollmentVerificationStatus: AWSDK.EnrollmentStatus {
        get {
            let status: AWSDK.EnrollmentStatus? = self.commonDataStore.fetch(itemQueryProvider.EnrollmentStatus)
            return status ?? AWSDK.EnrollmentStatus.unknown
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.EnrollmentStatus, value: newValue)
        }
    }
    
    var enrolledUserEmailAddress: String? {
        get {
            return self.commonDataStore.fetch(itemQueryProvider.EnrolledUserEmailAddress)
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.EnrolledUserEmailAddress, value: newValue)
            /// set onboardedUser value as well
            if let enrolledUserEmail: String = newValue, let serverURLStr: String = serverURL {
                onboardedUser = "\(serverURLStr):\(enrolledUserEmail)"
            } else {
                onboardedUser = serverURL /// if serverURL is nil; let onboardedUser be nil
            }
        }
    }
    
    var enrolledUser: String? {
        ///if we have an enrolled user email address return => "SeverURL:enrolledUserEmailAddress"
        if let enrolledUserEmail: String = enrolledUserEmailAddress, let serverURLStr: String = serverURL {
            return "\(serverURLStr):\(enrolledUserEmail)"
        } else { /// otherwise just return severURL without the colon, if serverURL is nil it will return nil
            return serverURL
        }
    }

    var enrollmentInformation: EnrollmentInformation? {
        get {
            let enrollmentInfo = EnrollmentInformation()
            enrollmentInfo.deviceIdentifier = self.deviceIdentifier
            enrollmentInfo.hostname = self.serverURL
            enrollmentInfo.organizationGroup = self.organizationGroup
            enrollmentInfo.lastVerifiedDate = self.enrollmentVerificationDate
            enrollmentInfo.lastKnownEnrollmentStatus = self.enrollmentVerificationStatus
            return enrollmentInfo
        }
        set {
            self.organizationGroup = newValue?.organizationGroup
            self.deviceIdentifier = newValue?.deviceIdentifier
            self.serverURL = newValue?.hostname
            self.enrollmentVerificationDate = newValue?.lastVerifiedDate
            self.enrollmentVerificationStatus = newValue?.lastKnownEnrollmentStatus ?? .unknown
        }
    }
    
    var shouldReportUnenrollment: Bool {
        get {
            let shouldReportUnenrollment:Bool? = self.commonDataStore.fetch(itemQueryProvider.ReportUnenrollment)
            return shouldReportUnenrollment ?? false
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.ReportUnenrollment, value: newValue)
        }
    }

}

internal extension String {
    
    //extracts scheme, host and port to create the final string
    //requires host and scheme at minimum
    //returns a URL string's origin
    func urlOriginString() -> String? {
        
        guard let urlComponents = URLComponents(string: self.lowercased()),
            let urlScheme = urlComponents.scheme, let urlHost = urlComponents.host
            else {
                return nil
        }
        var targetComponents = URLComponents()
        targetComponents.scheme = urlScheme
        targetComponents.host = urlHost
        targetComponents.port = urlComponents.port
        
        guard let urlOrigin = targetComponents.url else {
            return nil
        }
        return urlOrigin.absoluteString
    }
    
}
