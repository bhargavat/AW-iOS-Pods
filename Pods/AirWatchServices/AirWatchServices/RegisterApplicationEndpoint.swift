//
//  RegisterApplicationEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork
import AWHelpers
import AWError

extension AWServices {

    public enum RegistrationResult: Int {
        case unknown = 0
        case validateGroupIdentifier = 1
        case validateGroupIdentifierSelector = 2
        case doSamlAuthentication = 3
        case validateLoginCredentials = 4
        case validateOnBehalfOfUsername = 5
        case confirmOnBehalfOfUsername = 6
        case createNewEnrollmentUser = 7
        case validateAuthenticationToken = 8
        case validateDeviceDetails = 9
        case validateEulaAcceptance = 10
        case checkIfDirectoryUserExists = 11
        case checkEnrollmentStatus = 12
        case createMdmInstallUrl = 13
        case createAgentInstallUrl = 14
        case getUnmanagedProfileList = 15
        case getUnmanagedProfilePayload = 16
        case getPostEnrollmentUrl = 17
        case redirectToMdmInstallUrl = 18
        case redirectToAgentInstallUrl = 19
        case enrollmentBlocked = 20
        case displayWelcomeMessage = 21
        case displayMdmInstallationMessage = 22
        case validateStagingModeSelector = 23
        case registerApplication = 26
        case enrollmentComplete = 27
        case getPostSamlEnrollmentStep = 30
    }
}

internal let RegisterAppliationType = "2"
internal let RegisterAppliationMode = "2"
internal let RegisterAppliationProtocolType = "1"
internal enum PayloadKeys: String {
    case appBundleIdentifier            = "AppBundleIdentifier"
    case appInternalIdentifier          = "AppInternalIdentifier"
    case applicationHMACToken           = "DeviceAuthenticationToken"
    case device                         = "Device"
    case deviceIdentifier               = "Identifier"
    case enrollmentBundleIdentifier     = "BundleIdentifier"
    case enrollmentInternalIdentifier   = "InternalIdentifier"
    case header                         = "Header"
    case language                       = "Language"
    case payloadMode                    = "Mode"
    case payloadType                    = "Type"
    case protocolRevision               = "ProtocolRevision"
    case protocolType                   = "ProtocolType"
    case singleSignOnEnabled            = "SingleSignOnEnabled"
}

internal enum ProtocolRevision: String {
    case one = "1"
    case three = "3"
    case four = "4"
    case five = "5"
}

public typealias RegisterApplicationCompletionHandler = (ApplicationRegistrationResponse?, NSError?) -> Void

internal class RegisterApplicationEndpoint: EnrollmentServicesEndpoint {
    
    required init(config: EnrollmentServicesConfig) {
        super.init(config: config)
        self.serviceEndpoint = "deviceServices/AirwatchEnroll.aws/Enrollment/RegisterApplication"
    }
    
    func registerApplication(bundleIdentifier: String, commonIdentityAuthorizer: HMACAuthorizer, completion: @escaping RegisterApplicationCompletionHandler) {
        self.registerApplication(deviceIdentifier: self.config.deviceId, bundleIdentifier: bundleIdentifier, commonIdentityAuthorizer:commonIdentityAuthorizer, completion: completion)
    }
    
    func registerDeviceIdentifier(deviceIdentifier:String, bundleIdentifier: String, commonIdentityAuthorizer: HMACAuthorizer, completion: @escaping RegisterApplicationCompletionHandler) {
        self.registerApplication(deviceIdentifier: deviceIdentifier, bundleIdentifier: bundleIdentifier, commonIdentityAuthorizer:commonIdentityAuthorizer, completion: completion)
    }
    
    private func registerApplication(deviceIdentifier:String, bundleIdentifier: String, commonIdentityAuthorizer: HMACAuthorizer, completion: @escaping RegisterApplicationCompletionHandler) {
        
        guard self.endpointURL != nil else {
            log(error: "Invalid URL: \(self.config.airWatchServerURL), \(self.serviceEndpoint)")
            completion(nil, AWError.SDK.Service.General.invalidHTTPURL("\(self.config.airWatchServerURL), \(self.serviceEndpoint)").error)
            return
        }
        
        self.authorizer = commonIdentityAuthorizer
        
        let payloadData = self.createPayload(bundleIdentifier: bundleIdentifier, airwatchdeviceId: deviceIdentifier)
        
        self.POST(payloadData) {  (regstrationResult: ApplicationRegistrationResponseType?, error: NSError?) in
            guard error == nil else {
                log(error: "Error: \(error.debugDescription)")
                completion(nil, error)
                return
            }
            
            if let result = regstrationResult {
                completion(result, nil)
                return
            }
            
            completion(nil, AWError.SDK.Service.General.unexpectedResponse.error)
        }
        
    }
    
    
    private func createPayload(bundleIdentifier: String, airwatchdeviceId:String) -> Data? {
        var payload: [String: AnyObject] = [:]
        
        let headerDict: [String : String] = [
            PayloadKeys.protocolRevision.rawValue: ProtocolRevision.one.rawValue,
            PayloadKeys.language.rawValue: NSLocale.preferredLanguages[0],
            PayloadKeys.protocolType.rawValue: RegisterAppliationProtocolType,
            PayloadKeys.payloadMode.rawValue: RegisterAppliationMode]
        
        let deviceDict: [String : String] = [
            PayloadKeys.deviceIdentifier.rawValue: self.config.deviceId,
            PayloadKeys.payloadType.rawValue: RegisterAppliationType,
            PayloadKeys.enrollmentInternalIdentifier.rawValue: self.config.deviceId,
            PayloadKeys.enrollmentBundleIdentifier.rawValue: bundleIdentifier]
        
        payload[PayloadKeys.appBundleIdentifier.rawValue] = bundleIdentifier as AnyObject?
        payload[PayloadKeys.appInternalIdentifier.rawValue] = airwatchdeviceId as AnyObject?
        
        payload[PayloadKeys.header.rawValue] = headerDict as AnyObject?
        payload[PayloadKeys.device.rawValue] = deviceDict as AnyObject?
        
        return try? JSONSerialization.data(withJSONObject: payload, options: JSONSerialization.WritingOptions(rawValue: 0))
    }
}

public protocol ApplicationRegistrationResponse {
    var result: AWServices.RegistrationResult { get }
    var hmacToken: String? { get }
    var authenticationGroup: String? { get }
    var singleSignOnEnabled: Bool { get }
}

struct ApplicationRegistrationResponseType: ApplicationRegistrationResponse, CTLDataObjectProtocol {
    var result: AWServices.RegistrationResult
    let hmacToken: String?
    let authenticationGroup: String?
    let singleSignOnEnabled: Bool
    
    static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> ApplicationRegistrationResponseType {
        
        guard let jsonData = data else {
            throw AWError.SDK.Service.General.invalidJSONResponse
        }
        
        guard let response = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions(rawValue: 0)),
            let responseJSON = response as? [String: AnyObject] else {
            throw AWError.SDK.Service.General.jsonSerialization
        }
        
        guard let nextStepDetails = responseJSON["NextStep"]  else { throw AWError.SDK.Service.General.invalidJSONResponse }
        
        guard let type = nextStepDetails[PayloadKeys.payloadType.rawValue] as? Int
            else { throw AWError.SDK.Service.General.invalidJSONResponse}
        
        let result = AWServices.RegistrationResult(rawValue: type) ?? .unknown
        let hmacToken = nextStepDetails[PayloadKeys.applicationHMACToken.rawValue] as? String
        let authenticationGroup = nextStepDetails[PayloadKeys.enrollmentBundleIdentifier.rawValue] as? String
        var singleSignOnEnabled: Bool = false
        
        if let ssoenabled = nextStepDetails[PayloadKeys.singleSignOnEnabled.rawValue] as? String {
            singleSignOnEnabled = ["true", "yes", "1"].contains(ssoenabled.lowercased())
        }
        
        return ApplicationRegistrationResponseType(result: result, hmacToken: hmacToken, authenticationGroup: authenticationGroup, singleSignOnEnabled: singleSignOnEnabled)
        
    }
}
