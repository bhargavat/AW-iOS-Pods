//
//  DataUsageTransmitter.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWLog

internal class DataUsageTransmitterEndPoint: DeviceServicesEndpoint {
    
    //MARK: Public
    
    /**
     Should not be used unless in conjunction with AWDataUsage module
     */
    public func receiveDataFromServer(startDate: Date?,
                                      endDate: Date?,
                                      withCompletion completion: @escaping ((_ dictionary: Dictionary<AnyHashable, Any>?, _ error: Error?) -> Void)) -> Void {
        self.serviceEndpoint = "/deviceservices/awmdmsdk/v3/samples/datausage"
        guard let queryParameters = self.queryParameterForDataUsageDates(startDate, endDate: endDate) else {
            log(error: "Error creating queryParameters for DataUsageTransmitterEndpoint")
            completion(nil, AWError.SDK.Service.General.invalidHTTPURL("\(self.hostUrlString), \(self.serviceEndpoint)").error)
            return
        }
        guard let endpointURL = self.endPointURLWithQueryParameters(queryParameters) else {
            log(error: "Error creating endpointURL for DataUsageTransmitterEndpoint")
            completion(
                nil, AWError.SDK.Service.General.invalidHTTPURL("\(self.hostUrlString), \(self.serviceEndpoint)").error)
            return
        }
        AWLogVerbose("Preparing to make request to server to get the data usage")

        self.GET(endpointURL) { (rsp: Data?, error: NSError?) in
            guard let rspData = rsp , error == nil else {
                completion(nil, error)
                return
            }

            guard let rspDictionary = try? JSONSerialization.jsonObject(with: rspData, options: JSONSerialization.ReadingOptions.allowFragments) as? Dictionary<AnyHashable, Any> else {
                log(error: "Could not format servers data to Dictionary")
                completion(nil, error)
                return
            }

            completion(rspDictionary, error)
        }
    }

    /**
     Should not be used unless in conjunction with AWDataUsage module
     */
    public func sendDataToServer(_ dictionaryToSend: [AnyHashable: Any]?,
                                 withCompletion completion: @escaping ((_ success: Bool) -> Void)) {
        guard let dictionaryToSend = dictionaryToSend else {
            completion(false)
            return
        }

        self.serviceEndpoint = "/deviceservices/awmdmsdk/v3/samples/datausageperapp"
        guard let jsonDataToSend: Data = try? JSONSerialization.data(withJSONObject: dictionaryToSend, options: []) else {
            log(error: "Failed to send data to server, because data could not be converted")
            completion(false)
            return
        }

        self.additionalHTTPHeaders = ["Content-Type":"application/json", "Accept":"application/json"]

        self.POST(jsonDataToSend) { (rsp: Data?, error: NSError?) in
            if let error = error {
                log(error: "Server responded with error: \(error.debugDescription)")
                completion(false)
            } else {
                AWLogVerbose("Sent data usage to server successfully")
                completion(true)
            }
        }
    }

    //MARK: File Private
    fileprivate func queryParameterForDataUsageDates(_ startDate: Date?,
                                                 endDate: Date?) -> [String: String]? {
        var calendarGregorian: Calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        
        guard let timeZone: TimeZone = TimeZone(abbreviation: "UTC") else {
            log(error: "TimeZone does not exist")
            return nil
        }
        calendarGregorian.timeZone = timeZone

        var queryParameters: [String: String] = [:]
        let bundleID: String = self.config.bundleId
        queryParameters["bundleid"] = bundleID

        // Return the data between start and end dates
        if startDate != nil && endDate != nil {
            let fromDate: DateComponents = (calendarGregorian as NSCalendar).components([NSCalendar.Unit.month, NSCalendar.Unit.day, NSCalendar.Unit.year], from: startDate!)
            let toDate: DateComponents = (calendarGregorian as NSCalendar).components([NSCalendar.Unit.month, NSCalendar.Unit.day, NSCalendar.Unit.year], from: endDate!)

            let fromDateStr: String = NSString().appendingFormat("%d-%d-%dT00:00:00", fromDate.year!, fromDate.month!, fromDate.day!) as String
            let toDateStr: String = NSString().appendingFormat("%d-%d-%dT00:00:00", toDate.year!, toDate.month!, toDate.day!) as String

            queryParameters["fromdate"] = fromDateStr
            queryParameters["todate"] = toDateStr
        }
        // If both start and end date is not specified, then it is expected that the server will send most recent data
        else {
            log(debug: "Nil Dates for Data Usage Transmission")
        }
        return queryParameters
    }
}
