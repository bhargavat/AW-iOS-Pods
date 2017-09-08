//
//  EnrollmentServices.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork

public protocol EnrollmentServicesConfig {
    var airWatchServerURL: String { get }
    var deviceId: String { get }
}

public class EnrollmentServices {
    internal var config: EnrollmentServicesConfig

    public init(config: EnrollmentServicesConfig) {
        self.config = config
    }

    /**
     @brief Fetch the enrollment information
     
     @description Enrollment info will be console version, enrollment status, if managed, etc. which console will respond with. If by any chance the body is empty and a 200 status code is received, then EnrollmentInfo will have default values and enrollment status will be device not found.
     
     Possible errors 
     * AWError.SDK.Server.unexpectedServerResponse Console returned bad data for body or the response header was missing the console version or if status code is not 200
     * Failed to parse JSON with domain NSCocoaDomain with code 3840
     */
    public func fetchEnrollmentStatus(_ completionHandler: @escaping FetchEnrollmentInfoCompletionHandler) {
        let endpoint: FetchEnrollmentInfoEndpoint = createEnrollmentServiceEndpoint()
        endpoint.fetchEnrollmentInfo(completionHandler)
    }

    public func registerApplication(_ bundleIdentifier: String, commonIdentityAuthorizer: HMACAuthorizer, completion: @escaping RegisterApplicationCompletionHandler) {
        let endpoint: RegisterApplicationEndpoint = createEnrollmentServiceEndpoint()
        endpoint.registerApplication(bundleIdentifier: bundleIdentifier, commonIdentityAuthorizer: commonIdentityAuthorizer, completion: completion)
    }
    
    public func registerDeviceIdentifier(deviceIdentifier:String, bundleIdentifier: String, commonIdentityAuthorizer: HMACAuthorizer, completion: @escaping RegisterApplicationCompletionHandler) {
        let endpoint: RegisterApplicationEndpoint = createEnrollmentServiceEndpoint()
        endpoint.registerDeviceIdentifier(deviceIdentifier: deviceIdentifier, bundleIdentifier:bundleIdentifier, commonIdentityAuthorizer: commonIdentityAuthorizer, completion: completion)
    }

    internal func createEnrollmentServiceEndpoint<T>() -> T where T: EnrollmentServicesEndpoint {
        let endpoint = T(config: config)
        return endpoint
    }

}
