//
//  AWController+ObjCCompatibility.swift
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


// TODO: review whether to move these methods into other AWController files or deprecate them
extension AWController {
    @objc
    public func deviceServicesURL() -> String? {
        return context.consoleServicesConfig?.airWatchServerURL
    }

    // 3 possibilities passed back to the completion closure:
    //     completion(enrolled: false, error: <non-nil>) - Error in querying device enrollment services
    //     completion(enrolled: false, error: nil) - Succeeded querying. Device not enrolled.
    //     completion(enrolled: true, error: nil) - Device enrolled
    @objc public func queryDeviceEnrollmentStatus(_ completion: @escaping (_ enrolled: Bool, _ error: NSError?)-> Void) {
        guard let enrollmentServices = context.enrollmentServices else {
            completion(false, AWError.SDK.Controller.enrollmentServicesNotProperlySet.error)
            return
        }
        enrollmentServices.fetchEnrollmentStatus { (info, error) in
            guard let info = info else {
                completion(false, error)
                return
            }
            if info.enrollmentStatus == .enrolled {
                completion(true, nil)
            } else {
                // Not enrolled, but no error
                completion(false, nil)
            }
        }
    }

    @objc
    public func sendLogDataWithCompletion(_ completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {
        LogTransmitter.sharedInstance.dataStore = self.context
        LogTransmitter.sharedInstance.sendAnyUnsentLogs()
        LogTransmitter.sharedInstance.sendLogs(completion: completion)
    }

    @objc
    public var ssoStatus: AWSDK.SSOStatus {
        if context.enabledSingleSignOn {
            return .enabled
        } else {
            return .disabled
        }
    }
}

