//
//  AWMDMInformationController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWServices

internal extension AWSDK.RequeryType {

    var servicesRequery: AWServices.RequeryType {

        switch self {
            case .appList: return AWServices.RequeryType.applist
            case .deviceInfo: return AWServices.RequeryType.deviceInfo
            case .profileInfo: return AWServices.RequeryType.profileInfo
            case .securityInfo: return AWServices.RequeryType.securityInfo
        }
    }
}

fileprivate class DeviceInformationImpl: DeviceInformation {
    let servicesDeviceInformation: EnrollmentInfo
    fileprivate init(servicesDeviceInformation: EnrollmentInfo) {
        self.servicesDeviceInformation = servicesDeviceInformation
    }

    var enrollmentStatus: AWSDK.EnrollmentStatus {
        return AWSDK.EnrollmentStatus(rawValue: servicesDeviceInformation.enrollmentStatus.rawValue) ?? .unknown
    }

    var complianceStatus: AWSDK.ComplianceStatus {
        return AWSDK.ComplianceStatus(rawValue: servicesDeviceInformation.complianceStatus.rawValue) ?? .unknown
    }

    var isManaged: Bool {
        return servicesDeviceInformation.isManaged
    }

    var managementType: AWSDK.DeviceManagmentType {
        return AWSDK.DeviceManagmentType(rawValue: servicesDeviceInformation.managedBy.rawValue) ?? .unknown
    }

    var groupName: String {
        return servicesDeviceInformation.deviceLocationGroup
    }

    var groupID: String {
        return servicesDeviceInformation.deviceGroupID
    }
}


public final class DeviceInformationController: NSObject {
    public static let sharedController = DeviceInformationController()
    private override init() {}

    @objc
    public var deviceServicesURL: String? {
        return AWController.sharedInstance.context.consoleServicesConfig?.airWatchServerURL
    }

    @objc
    public var ssoStatus: AWSDK.SSOStatus {
        return AWController.sharedInstance.context.enabledSingleSignOn ? .enabled : .disabled
    }

    @objc
    public static func isCurrentDeviceCompromised() -> Bool {
        return awIsCompromised()
    }

    public func fetchDeviceInformation(completion: @escaping (_ information: DeviceInformation?, _ error: Error?) -> Void) {

        guard let enrollmentServices = AWController.sharedInstance.context.enrollmentServices else {
            completion(nil, AWError.SDK.Controller.enrollmentServicesNotProperlySet.error)
            return
        }

        enrollmentServices.fetchEnrollmentStatus { (information, error) in
            guard let info = information else {
                completion(nil, error)
                return
            }
            completion(DeviceInformationImpl(servicesDeviceInformation: info), nil)
        }
    }


    public func requestRequery(type: AWSDK.RequeryType, completion:@escaping (_ success: Bool, _ error: Error?) -> Void) {

        guard let deviceServices = AWController.sharedInstance.context.deviceServices else {
            completion(false, AWError.SDK.Controller.deviceServicesNotProperlySet.error)
            return
        }

        deviceServices.requestRequeryDeviceInformation(type: type.servicesRequery, completion: completion)
    }
}
