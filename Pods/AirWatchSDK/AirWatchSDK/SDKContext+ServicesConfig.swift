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

extension SDKContext {
    var enrollmentServices: EnrollmentServices? {
        guard let config = self.consoleServicesConfig else {
            return nil
        }

        let enrollmentServices = EnrollmentServices(config: config)
        return enrollmentServices
    }

    var commonEnrollmentServices: EnrollmentServices? {
        mutating get {
            guard let config = self.commonConsoleServicesConfig else {
                return nil
            }

            let enrollServices = EnrollmentServices(config: config)
            return enrollServices
        }
    }

    public var deviceServices: DeviceServices? {

        guard let services = self.createDeviceServices(config: self.consoleServicesConfig, identity: self.applicationIdentity) else {
            log(error: "Can not construct Device Services from application identity.")
            return nil
        }

        return services
    }

    public var commonDeviceServices: DeviceServices? {
        guard let services = self.createDeviceServices(config: self.commonConsoleServicesConfig, identity: self.commonIdentity) else {
            log(error: "Can not construct Device Services from common identity.")
            return nil
        }

        return services
    }

    private func createDeviceServices(config: DeviceServicesConfiguration?, identity: Identity?) -> DeviceServices? {

        guard let config = self.consoleServicesConfig else {
            return nil
        }

        let hmacAuthorizer = SDKHMACAuthorizer(identity: identity)
        if let authorizer = hmacAuthorizer {
            config.authenticationGroup = authorizer.authGroup
        }

        return DeviceServices(config: config,
                              authorizer: hmacAuthorizer,
                              secureChannelConfigurationManager: self.secureChannelConfigurationManager)
    }

    var secureChannelConfigurationManager: SecureChannelConfigurationManager? {
        guard let serverURL = self.enrollmentInformation?.hostname,
            let deviceID = self.enrollmentInformation?.deviceIdentifier else {
                return nil
        }

        return SDKSecureChannelConfigurationManager.configurationManager(url: serverURL, deviceIdentifier: deviceID)
    }

    var consoleServicesConfig: ConsoleServicesConfig? {
        guard let enrollmentInformation = self.enrollmentInformation else {
            log(error: "Missing Enrollment Information")
            return nil
        }

        return ConsoleServicesConfig(enrollmentInfo: enrollmentInformation)
    }

    var commonConsoleServicesConfig: ConsoleServicesConfig? {

        guard
            let enrollmentInformation = self.enrollmentInformation,
            let commonIdentityHMAC = self.commonIdentity?.authorization,
            let commonIdentityAuthenticationGroup = commonIdentityHMAC.authorizationGroup,
            let config = ConsoleServicesConfig(enrollmentInfo: enrollmentInformation)
        else {
            log(error: "Can not create Common Console Services Config")
            return nil
        }

        config.authenticationGroup = commonIdentityAuthenticationGroup
        return config
    }
}
