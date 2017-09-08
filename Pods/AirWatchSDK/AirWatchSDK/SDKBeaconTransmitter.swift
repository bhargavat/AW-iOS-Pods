//
//  SDKBeacon.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWError

fileprivate let LastSuccessfulBeaconTransmisssionTimeStamp = "AWBeaconSuccessfulTimeStamp"
fileprivate let ShouldSendGPSInformationInBeacon = "BeaconShouldSendGPS"

internal enum BeaconTransmissionNotification: String, PostableNotification {
    var name: String { return self.rawValue }
    case didSendBeaconSuccessfully = "AWBeaconDidSendNotification"
    case didFailToSend = "AWBeaconDidFailToSendNotification"
}

public let AWBeaconErrorUserInfoKey = "AWBeaconErrorUserInfoKey"

@objc(AWSDKBeaconTransmitter)
public class SDKBeaconTransmitter: NSObject {
    private enum ComplianceStatus: Int {
        case unknown = 0
        case compliant = 3
        case nonCompliant = 4
    }

    private let CompromisedComplianceIdentifier =  "com.airwatch.compliance.compromisedPolicy"
    private let PasscodeComplianceIdentifier = "com.airwatch.compliance.passcodePolicy"

    public static let sharedTransmitter = SDKBeaconTransmitter()
    public typealias SendBeaconCompletion = (Bool, Error?)-> Void

    private static let DS_ROOT_KEY = "d"
    private static let DS_STATUS_KEY = "Status"

    deinit {
        self.timer?.invalidate()
    }

    @objc
    public func sendBeacon(updatedAPNSToken: String, completion: SendBeaconCompletion?) {
        var context = AWController.sharedInstance.context
        context.latestAPNSToken = updatedAPNSToken
        self.sendDeviceStatusBeacon(completion: completion)
    }

    private var timer: Timer? = nil
    @objc
    public func startSendingDeviceStatusBeacon(transmitFrequency: TimeInterval = 60) {
        self.timer?.invalidate()
        self.timer = nil

        //Send beacon once and then schedule.
        self.sendDeviceStatusBeacon(completion: nil)

        guard transmitFrequency != 0 else { return }

        //Minimumm 60 seconds between beacons.
        let frequency = min(60, transmitFrequency)
        self.timer = Timer.scheduledTimer(timeInterval: frequency, target: self, selector: #selector(sendDeviceStatusBeacon(completion:)), userInfo: nil, repeats: true)
    }

    @objc
    public func stopSendingDeviceStatusBeacon() {
        self.timer?.invalidate()
    }


    @objc
    public func sendDeviceStatusBeacon(completion: SendBeaconCompletion?) {

        var context = AWController.sharedInstance.context
        let groupID = context.enrollmentInformation?.organizationGroup
        let emailAddress = context.currentUserInformation?.email

        let beaconID = String(format: "%.0f", Date().timeIntervalSince1970)
        let apnsToken = context.latestAPNSToken
        let generalPayload = AWServices.SendBeaconPayload.generalInfo(APNToken: apnsToken, locationGroup: groupID, transID: beaconID)
        let userPayload = AWServices.SendBeaconPayload.userInfo(email: emailAddress, phone: nil)

        let compromisedComplianceStatus: ComplianceStatus = DeviceInformationController.isCurrentDeviceCompromised() ? .nonCompliant : .compliant
        let compromisedComplianceTuple = (policyIdentifier: CompromisedComplianceIdentifier, complianceStatus: compromisedComplianceStatus.rawValue)

        let compliancePoliciesPayload = AWServices.SendBeaconPayload.compliancePolicies(policies: [compromisedComplianceTuple])

        let combinationPayload: AWServices.SendBeaconPayload = .combination(general: generalPayload, user: userPayload, gps: nil, compliancePolicies: compliancePoliciesPayload)

        guard let deviceServices = context.deviceServices else {
            completion?(false, AWError.SDK.Policy.Management.Generic.missingDeviceServices)
            return
        }

        deviceServices.sendBeacon(combinationPayload) {[weak self] (data, error) in

            if let error = error {
                log(error: "Failed to send beacon - error: \(error)")
                let errorDictionary = [AWBeaconErrorUserInfoKey: error]
                BeaconTransmissionNotification.didFailToSend.post(data: errorDictionary as AnyObject)
                completion?(false, error)
                return
            }
            guard let rawResponseInfo = data?.JSON as? NSDictionary,
                let responseInfo = rawResponseInfo[SDKBeaconTransmitter.DS_ROOT_KEY] as? NSDictionary,
                let statusResponse = responseInfo[SDKBeaconTransmitter.DS_STATUS_KEY] as? NSNumber else {
                    log(error: "Beacon response from console could not be parsed")
                    BeaconTransmissionNotification.didFailToSend.post(data: nil)
                    completion?(false, AWError.SDK.Service.General.invalidJSONResponse)
                    return
            }

            let statusResponseCode = statusResponse.intValue
            guard statusResponseCode == 1 else {
                log(warning:"Beacon successfully sent, but with response code \(statusResponseCode) from console")
                BeaconTransmissionNotification.didFailToSend.post(data: nil)
                completion?(false, AWError.SDK.Service.General.unexpectedResponse)
                return
            }

            log(info: "Beacon response is success")
            self?.setSuccessfulBeaconSent(timestamp: Date())
            BeaconTransmissionNotification.didSendBeaconSuccessfully.post(data: nil)
            completion?(true, nil)
        }
    }


    func setSuccessfulBeaconSent(timestamp: Date?) {

        if let timestamp = timestamp {
            UserDefaults.standard.set(timestamp, forKey: LastSuccessfulBeaconTransmisssionTimeStamp)
        } else {
            UserDefaults.standard.removeObject(forKey: LastSuccessfulBeaconTransmisssionTimeStamp)
        }

        UserDefaults.standard.synchronize()
    }

    @objc
    open func lastSuccessfulBeaconTimeStamp() -> Date? {
        return UserDefaults.standard.object(forKey: LastSuccessfulBeaconTransmisssionTimeStamp) as? Date
    }

}
