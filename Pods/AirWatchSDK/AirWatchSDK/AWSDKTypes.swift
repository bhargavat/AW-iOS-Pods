//
//  AWSDKTypes.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc
public class AWSDK: NSObject {

    @objc(AWEnrollmentStatus)
    public enum EnrollmentStatus: Int {
        case deviceNotFound = 0
        case discovered
        case registered
        case enrollmentInProgress
        case enrolled
        case enterpriseWipePending
        case deviceWipePending
        case retired
        case unenrolled
        case unknown
    }

    @objc(AWComplianceStatus)
    public enum ComplianceStatus: Int {
        case unknown = 0
        case allowed
        case blocked
        case compliant
        case nonCompliant
        case notAvailable
        case notApplicable
        case pendingComplianceCheck
        case pendingComplianceCheckForAPolicy
        case registrationActive
        case registrationExpired
        case quarantined
    }

    @objc(AWDeviceManagmentType)
    public enum DeviceManagmentType: Int {
        case notManaged = 0
        case managedByMDM
        case managedByMAM
        case quarantine
        case unknown
    }

    @objc(AWSSOStatus)
    public enum SSOStatus: Int {
        case unknown = 0
        case enabled
        case disabled
    }

    @objc(AWRequeryType)
    public enum RequeryType: Int {
        @objc(AWRequeryApplist)         case appList = 1
        @objc(AWRequeryDeviceInfo)      case deviceInfo = 2
        @objc(AWRequeryProfileInfo)     case profileInfo = 3
        @objc(AWRequerySecurityInfo)    case securityInfo = 4
    }

    @objc(AWNetworkActivityStatus)
    public enum NetworkActivityStatus: Int {
        @objc(AWNetworkActivityInit)                case unknown    /// Initial/unknown state
        @objc(AWNetworkActivityNormal)              case normal     /// Normal
        @objc(AWNetworkActivityNetworkNotReachable) case networkNotReachable /// When Either there is no network (no wifi or cellular) or in airplane mode.
        @objc(AWNetworkActivityBadSSID)             case connectedToUnknownSSID /// SSID does not match what is listed
        @objc(AWNetworkActivityCellularDisabled)    case cellularDataConnectionDisabled /// Celluar data is completely disabled
        @objc(AWNetworkActivityRoaming)             case cellularDataConnectionDisabledWhileRoaming  /// Celluar data is disabled while roaming
        @objc(AWNetworkActivityProxyFailed)         case proxySetupFailed /// Proxy setup failed.
    }

    @objc(AWAuthenticationMethod)
    public enum AuthenticationMethod: Int {
        case none
        case passcode
        case usernamePassword
    }

    @objc(AWBiometricMethod)
    public enum BiometricMethod: Int {
        case none = 0
        case touchID = 2
    }

    @objc(AWPasscodeMode)
    public enum PasscodeMode: Int {
        case off
        case numeric
        case alphanumeric
    }

    @objc(AWProxyType)
    public enum ProxyType: Int {
        case none
        case mag
        case f5
        case standard
    }

}

@objc(AWDeviceInformation)
public protocol DeviceInformation {
    var enrollmentStatus: AWSDK.EnrollmentStatus { get }
    var complianceStatus: AWSDK.ComplianceStatus { get }
    var isManaged: Bool { get }
    var managementType: AWSDK.DeviceManagmentType { get }
    var groupName: String { get }
    var groupID: String { get }
}
