//
//  AWLogInsightTransmitter.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit
import AWHelpers
import AWNetwork
import AWError


class LogInsightTransmissionEndpoint: DeviceServicesEndpoint {
    fileprivate static let logInsightQueue = DispatchQueue(label: "DeviceServices.SendLogInsightData.SyncQueue", attributes: [])

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
    }

    func sendLogInsightData(_ logInsightData: Data, overWifiOnly: Bool, completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {
        ///if Send over WIFI only: check WIFI status
        if overWifiOnly {
            log(debug: "SendLogsOverWifiOnly set to True; Checking Reachability via Wifi")
            guard Reachability.forInternetConnection?.currentReachabilityStatus == .reachableViaWifi else {
                log(error: "Network Not reachable via wifi. Cannot Send logs")
                completion(false, AWError.SDK.Reachability.networkNotReachable.error)
                return
            }
        }

        /// checks for getting entries from plist
        guard let logInsightPlist = SDKDefaultSettings.sharedSettings.getLogInsightURLDefaults() else {
            log(error: "Unable to retrieve logInsightPlist to send LogInsight data")
            let error = AWError.SDK.Service.Endpoint.LogInsightTransmitter.invalidServerURL("logInsightPlist is nil").error
            completion(false, error)
            return
        }

        guard let serverURL: String = logInsightPlist["URL"] as? String else {
            log(error: "Unable to retrieve server host URL from logInsightPlist to send LogInsight data")
            let error = AWError.SDK.Service.Endpoint.LogInsightTransmitter.invalidServerURL("(Unable to get Server host URL from logInsightPlist)").error
            completion(false, error)
            return
        }

        guard let serverPort: String = logInsightPlist["Port"] as? String else {
            log(error: "Unable to retrieve server port from logInsightPlist to send LogInsight data")
            let error = AWError.SDK.Service.Endpoint.LogInsightTransmitter.invalidServerPort("(Unable to get Server Port from logInsightPlist)").error
            completion(false, error)
            return
        }

        guard let serverPath: String = logInsightPlist["Path"] as? String else {
            log(error: "Unable to retrieve server path from logInsightPlist to send LogInsight data")
            let error = AWError.SDK.Service.Endpoint.LogInsightTransmitter.invalidServerPath("(Unable to get Server Path from logInsightPlist)").error
            completion(false, error)
            return
        }

        self.additionalHTTPHeaders = [:]
        self.additionalHTTPHeaders?["AppPath"] = serverPath
        self.additionalHTTPHeaders?["UDUD"] = self.config.deviceId
        guard let logInsightURL = URL(string: "\(serverURL):\(serverPort)/LogInsight") else {
            log(error: "Can not Construct LogInsight URL")
            return
        }

        log(debug: "Sending data to LogInsight...")
        self.POST(logInsightURL, data: logInsightData) { (rsp: Data?, error: NSError?) in
            if let error = error {
                log(error: "Server responded with error: \(error.debugDescription)")
                completion(false, error)
            } else {
                log(info: "Sent log Insight data to server successfully")
                completion(true, error)
            }
        }
    }
}
