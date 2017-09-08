//
//  LogTransmissionEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork
import AWError
import AWHelpers
import AWLog


///Retry suggested when reachability changes
public typealias LogTransmissionCompletionHandler = (_ success: Bool, _ error: NSError?) -> Void

private let authGroupHardCoded = "com.air-watch.mdm.6.4"

class LogTransmissionEndpoint: DeviceServicesEndpoint {

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        let newAuthorizer: CTLAuthorizationProtocol?
        if let givenAuthorizer = authorizer {
            newAuthorizer = givenAuthorizer
        } else {
            newAuthorizer = DeviceServicesHMACAuthorizer(deviceId: config.deviceId, authGroup: authGroupHardCoded, hmac: "9E7DE4E6-0994-4F74-A1CB-4AA3B25F12D8".data(using: String.Encoding.utf8)!)
        }

        super.init(config: config, authorizer: newAuthorizer, validator: validator)
        self.serviceEndpoint = "/deviceServices/awmdmsdk/v1/platform/\(config.deviceType)/uid/\(config.deviceId)/logging"

    }


    func send(logData: Data, settingLogLevel: Int, overWifiOnly: Bool, logType: AWLogType, withCompletion completion: @escaping LogTransmissionCompletionHandler) -> Void {
        ///if Send over WIFI only: check WIFI status
        if overWifiOnly {
            log(debug: "SendLogsOverWifiOnly set to True; Checking Reachability via Wifi")
            guard Reachability.forInternetConnection?.currentReachabilityStatus == .reachableViaWifi else {
                log(error: "Network Not reachable via wifi. Cannot Send logs")
                completion(false, AWError.SDK.Reachability.networkNotReachable.error)
                return
            }
        }

        ///gather values for dictionary to send to console
        let version = SDKDefaultSettings.version()
        guard let logString = String(data: logData, encoding: .utf8), logString.characters.count > 0 else {
            log(error: "Error: Invalid log string lengths to send to data")
            return
        }
        
        let logDictionaryToSend: Dictionary = [ "BundleId" : self.config.bundleId,
                                                "AppVersion" : String(version),
                                                "LogType" : String(logType.rawValue),
                                                "LogLevel" : String(settingLogLevel),
                                                "LogData" : logString
        ]

        do {
            let uploadData: Data = try JSONSerialization.data(withJSONObject: logDictionaryToSend, options: JSONSerialization.WritingOptions.prettyPrinted)
            self.POST(uploadData) { (rsp: Data?, error: NSError?) in
                if let error = error {
                    log(error: "Server responded with error: \(error.debugDescription)")
                    completion(false, error)
                } else {
                    AWLogVerbose("Sent log data usage to server successfully")
                    completion(true, error)
                }
            }
        } catch {
            log(error: "Error: Failed to convert logging dictionary to data. Cannot upload logs to console")
            completion(false, AWError.SDK.Service.General.jsonSerialization.error)
        }
    }

    fileprivate class func hmacKey() -> Data? {

        let deObfuscator = hmacGenerator()

        let decryptData = deObfuscator.decrypt("llZgGxqt5tJFUTPG6aPFJeC/YlLo9eXQGZNmoWkFt/DvEsMaNQS9uYq1KPpg7nqx")

        return decryptData
    }

    fileprivate struct hmacGenerator: InlineCipherDeObfuscator {
        let phrase: String = "AWReceivedNotification"
        let salt: String = "UYr4df8+D+hJU4df8T+D+hJXm"
    }
}
