//
//  FetchEnrollmentInfoEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWNetwork

public final class AWServices {

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

    public enum DeviceManagmentType: Int {
        case notManaged = 0
        case managedByMDM
        case managedByMAM
        case quarantine
    }
}


public protocol EnrollmentInfo {
    var isManaged: Bool { get }
    var enrollmentStatus: AWServices.EnrollmentStatus { get }
    var complianceStatus: AWServices.ComplianceStatus { get }
    var consoleVersion: String { get }
    var deviceLocationGroup: String { get }
    var deviceGroupID: String { get }
    var managedBy: AWServices.DeviceManagmentType {get}
}

public typealias FetchEnrollmentInfoCompletionHandler = (_ info: EnrollmentInfo?, _ error: NSError?) -> Void

internal final class EnrollmentInformationImpl: EnrollmentInfo, CTLDataObjectProtocol {
    internal fileprivate(set) var isManaged: Bool = false
    internal fileprivate(set) var enrollmentStatus: AWServices.EnrollmentStatus = .unknown
    internal fileprivate(set) var complianceStatus: AWServices.ComplianceStatus = .unknown
    internal fileprivate(set) var consoleVersion: String = "0.0.0"
    internal fileprivate(set) var deviceLocationGroup: String = ""
    internal fileprivate(set) var deviceGroupID: String = ""
    internal fileprivate(set) var managedBy: AWServices.DeviceManagmentType = .notManaged
    
    internal init() {
        
    }
    
    /*
     @parameter json value for AnyObject can handle strings for values for basic types like Int and Bool 
     */
    internal init(json: [String:AnyObject]) throws {
        // Must handle both cases if someone passes a string or the type for these variables
        var tempIsManaged: Bool? = json["ismanaged"] as? Bool
        var tempEnrollmentStatus = json["enrollmentstatus"] as? Int
        var tempComplianceStatus = json["compliancestatus"] as? Int
        var tempManagedBy = json["managedby"] as? Int
        
        if tempIsManaged == nil, let isManagedString = json["ismanaged"] as? String {
            tempIsManaged = (isManagedString.lowercased() == "true")
        }
        
        if tempEnrollmentStatus == nil, let enrollmentStatusString = json["enrollmentstatus"] as? String {
            tempEnrollmentStatus = Int(enrollmentStatusString)
        }
        
        if tempComplianceStatus == nil, let complianceStatusString = json["compliancestatus"] as? String {
            tempComplianceStatus = Int(complianceStatusString)
        }
        
        if tempManagedBy == nil, let managedByString = json["managedby"] as? String {
            tempManagedBy = Int(managedByString)
        }
        
        guard
            let consoleVersion = json["consoleversion"] as? String,
            let groupCode = json["groupcode"] as? String,
            let deviceLocationGroup = json["devicelocationgroup"] as? String,
            let isManaged = tempIsManaged,
            let managedBy = tempManagedBy,
            let enrollmentStatus = tempEnrollmentStatus,
            let complianceStatus = tempComplianceStatus
        else {
            throw AWError.SDK.Server.unexpectedServerResponse.error
        }
        
        self.isManaged = isManaged
        self.enrollmentStatus = AWServices.EnrollmentStatus(rawValue: enrollmentStatus) ?? .unknown
        self.complianceStatus = AWServices.ComplianceStatus(rawValue: complianceStatus) ?? .unknown
        self.deviceLocationGroup = deviceLocationGroup
        self.deviceGroupID = groupCode
        self.managedBy = AWServices.DeviceManagmentType(rawValue: managedBy) ?? .notManaged
        self.consoleVersion = consoleVersion
    }
    
    static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> EnrollmentInformationImpl {
        // If the data is nil or the json cannot be parsed, then we will return unexpected server response.
        // if try? is not part of the JSONSerialization, then we will not be able to throw our own custom error
        guard
            let response = additionalProperties?[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse,
            let consoleVersion = response.allHeaderFields["x-aw-version"] as? String,
            response.statusCode == 200
        else {
            throw AWError.SDK.Server.unexpectedServerResponse
        }
        
        guard let data = data, data.count > 0  else {
            let enrollmentInfo = EnrollmentInformationImpl()
            enrollmentInfo.enrollmentStatus = .deviceNotFound
            enrollmentInfo.consoleVersion = consoleVersion
            return enrollmentInfo
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        guard let JSONArrayFromConsole = json as? [[String:AnyObject]] else {
            throw AWError.SDK.Server.unexpectedServerResponse
        }
        
        var enrollmentInformationResponse: [String: AnyObject] = [:]
        JSONArrayFromConsole.forEach { (item: [String: AnyObject]) in
            if let key = item["DeviceSetting"] as? String {
                let value = item["SettingValue"]
                enrollmentInformationResponse[key] = value
            }
        }
        
        enrollmentInformationResponse["consoleversion"] = consoleVersion as AnyObject
        
        return try EnrollmentInformationImpl(json: enrollmentInformationResponse)
    }
}

internal class FetchEnrollmentInfoEndpoint: EnrollmentServicesEndpoint {
    internal required init(config: EnrollmentServicesConfig) {
        super.init(config: config)
        self.serviceEndpoint = "deviceservices/awmdmsdk/v1/platform/2/uid/\(config.deviceId)/status"
    }

    internal func fetchEnrollmentInfo(_ completionHandler: @escaping FetchEnrollmentInfoCompletionHandler) {
        self.GET { (enrollmentInformationImpl: EnrollmentInformationImpl?, error: NSError?) in
            guard let enrollmentInformationImpl = enrollmentInformationImpl, error == nil else {
                completionHandler(nil, error)
                return
            }
            
            completionHandler(enrollmentInformationImpl, nil)
        }
    }
}
