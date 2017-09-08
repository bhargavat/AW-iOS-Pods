//
//  CredentialProfileEndPoint.swift
//  AirWatchServices
//
//  Copyright © 2017 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork
import AWError
import AWCMWrapper

public extension AWServices {
    public enum ProfileType: String {
        case authentication = "Authentication"
        case signing = "Signing"
        case encryption = "Encryption"
        case all = "All"
    }
}

internal class CredentialProfileConstants {

    static let kAWQueryParamKeyUsage: String    = "KeyUsage"
    static let kAWQueryParamUpdate: String      = "Update"
    static let kAWQueryValueTrue: String        = "true"

    static let kAWURI: String                   = "Uri"
    static let kAWEncryptionCertificate: String = "EncryptionCertificate"
    static let kAWProfilePayloadList: String    = "ProfilePayloadList"
}


public protocol CredentialProfileInformation: class {
    var url: String { get }
    var profileList: Array<[String:AnyObject]> { get }
    var publicKey: String { get }
}


final class CredentialProfileInformationImpl: CredentialProfileInformation, CTLDataObjectProtocol {
    public private(set) var url: String
    public private(set) var publicKey: String
    public private(set) var profileList: Array<[String: AnyObject]>

    private init(jsonDict: [String: AnyObject]) throws {
        guard
            let url = jsonDict[CredentialProfileConstants.kAWURI] as? String,
            let profileList = jsonDict[CredentialProfileConstants.kAWProfilePayloadList] as? Array<[String:AnyObject]>
        else {
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }

        self.url = url
        self.profileList = profileList

        //PublicKey from server will be nil only when there are no profiles.
        guard let publicKey = jsonDict[CredentialProfileConstants.kAWEncryptionCertificate] as? String else {
            guard profileList.count == 0 else {
                throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
            }
            self.publicKey = ""
            return
        }

        self.publicKey = publicKey
    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> CredentialProfileInformationImpl {

        guard let data = data else {
            throw AWError.SDK.Service.Endpoint.UserInfo.missingResponseData
        }
        
        let jsonResult = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions.mutableContainers)

        guard let jsonDict = jsonResult as? [String: AnyObject] else {
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }

        return try CredentialProfileInformationImpl(jsonDict: jsonDict)
    }
}

@objc
final class SendCredentialProfilesResponse: NSObject, CTLDataObjectProtocol {

    var success: Bool = false

    private init(statusCode: NSInteger) throws {
        guard statusCode >= 200 && statusCode < 300 else {
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }

        self.success = true
    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> SendCredentialProfilesResponse {

        guard let addProps = additionalProperties else {
            throw AWError.SDK.Service.Endpoint.UserInfo.genericError
        }
        
        guard let response = addProps[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse else{
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }

        return try SendCredentialProfilesResponse(statusCode: response.statusCode)
    }
}

public typealias FetchCredentialProfileInformationCompletion = (_ dcProfileInfo: CredentialProfileInformation?,_ error: NSError?) -> Void
public typealias SendCredentialProfilesCompletion = (_ success: Bool,_ error: NSError?) -> Void

internal class CredentialProfileEndPoint: DeviceServicesEndpoint {

    let kCredentialProfileEndpoint = "deviceservices/DerivedCredentials/Profiles"

    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = kCredentialProfileEndpoint
    }

    public func fetchCredentialProfileInformation(type: AWServices.ProfileType = .all, update: Bool = false, completion: @escaping FetchCredentialProfileInformationCompletion) -> Void {

        self.serviceEndpoint = kCredentialProfileEndpoint
        var queryParameters: [String: String] = [:]

        if type != .all {
            queryParameters[CredentialProfileConstants.kAWQueryParamKeyUsage] = type.rawValue
        }

        if update == true {
            queryParameters[CredentialProfileConstants.kAWQueryParamUpdate] = CredentialProfileConstants.kAWQueryValueTrue
        }

        guard let endpointURL = self.endPointURLWithQueryParameters(queryParameters) else {
            log(error: "Error Fetching Certificate: Invalid URL String")
            completion(nil, AWError.SDK.Service.General.invalidHTTPURL("\(self.hostUrlString), \(self.serviceEndpoint)").error)
            return
        }

        self.GET(endpointURL) { (response: CredentialProfileInformationImpl?, error: NSError?) in
            guard error == nil else {
                completion(nil, error)
                return
            }

            guard let response = response else {
                completion(nil, AWError.SDK.Service.General.invalidJSONResponse.error)
                return
            }

            completion(response, nil)
        }
    }

    public func sendCredentialProfiles(uploadProfiles:Array<[String:String]>, completion: @escaping SendCredentialProfilesCompletion) -> Void {

        guard uploadProfiles.count > 0 else {
            log(error: "There are not profiles to be sent, aborted send profile.")
            completion(false, AWError.SDK.Service.Endpoint.UserInfo.genericError.error)
            return
        }

        do {
            let httpBody = try JSONSerialization.data(withJSONObject:uploadProfiles, options:[])

            self.serviceEndpoint = kCredentialProfileEndpoint
            self.POST(httpBody) { (response: SendCredentialProfilesResponse?, error: NSError?) in
                guard error == nil else {
                    completion(false, error)
                    return
                }

                guard let response = response,
                    response.success == true else {
                        completion(false, AWError.SDK.Service.Endpoint.UserInfo.missingResponseData.error)
                        return
                }

                completion(true, nil)
            }
        } catch {

            log(error: "Profiles are not sent to server due to json serialization failed.")
            completion(false, AWError.SDK.Service.General.jsonSerialization.error)
            return
        }

    }
}
