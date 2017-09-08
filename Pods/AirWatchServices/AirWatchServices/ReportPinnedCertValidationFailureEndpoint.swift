//
//  ReportPinnedCertValidationFailureEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWLog

public class PinnedCertValidationFailureEndpoint {
    static internal var lastReportedHost = ""
    
    static public func reportCertValidationFailureToServer(awServerUrl:String, onDeviceId deviceId:String, forChallengedHost host:String) -> Bool {
        
        guard awServerUrl.characters.count > 0 && deviceId.characters.count > 0 && host.characters.count > 0 else {
            return false
        }
        
        if lastReportedHost == host {
            return true
        }
        
        let newNetworkSession = URLSession(configuration: URLSessionConfiguration.ephemeral)
        
        let eventReportingURL = NSURL(string: "\(awServerUrl)/DeviceServices/CertificatePinningReportingEndpoint?url=\(host)")
        
        guard let reportingUrl = eventReportingURL else {
            return false
        }
        
        let reportingRequest = NSMutableURLRequest(url: reportingUrl as URL)
        reportingRequest.httpMethod = "GET"
        
        reportingRequest.addValue("2", forHTTPHeaderField: "deviceType")
        reportingRequest.addValue(deviceId, forHTTPHeaderField: "aw-device-uis")
        
        let reportingTask = newNetworkSession.dataTask(with: reportingRequest as URLRequest, completionHandler: { (responseData, urlResponse, error) in
            log(info: "completed report of SSL Pinning validation failure to console.")
            if let error = error {
                log(error: "SSL Pinning failure report received error from server: \(error)")
            }
        })
        reportingTask.resume()
        lastReportedHost = host
        return true
    }
}
