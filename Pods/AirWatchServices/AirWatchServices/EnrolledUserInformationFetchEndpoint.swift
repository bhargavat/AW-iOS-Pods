//
//  SearchUserByIdEndpoint.swift
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


@objc
public protocol EnrolledUserInformation: class {
    var userName: String { get }
    var userIdentifier: String { get }
    var firstName: String { get }
    var lastName: String { get }
    var email: String { get }
    var domain: String { get }
    var groupID: String { get }
}

@objc
final class EnrolledUserInformationImpl: NSObject, EnrolledUserInformation, CTLDataObjectProtocol {
    public private(set) var userName: String
    public private(set) var userIdentifier: String
    public private(set) var firstName: String
    public private(set) var lastName: String
    public private(set) var email: String
    public private(set) var domain: String
    public private(set) var groupID: String

    /* Example Response:
     {
     "Domain": "AtlantaWifi",
     "Email": "test@air-watch.com",
     "FirstName": "Bob",
     "GroupCode": "571",
     "LastName": "Smith",
     "UserId": "3",
     "UserName": "user"
     }
     */
    
    private init(jsonDict: [String: AnyObject]) throws {
        guard
            let domain = jsonDict["Domain"] as? String,
            let email = jsonDict["Email"] as? String,
            let firstName = jsonDict["FirstName"] as? NSString,
            let groupCode = jsonDict["GroupCode"] as? String,
            let lastName = jsonDict["LastName"] as? NSString,
            let userIdentifier = jsonDict["UserId"] as? String,
            let userName = jsonDict["UserName"] as? String
        else {
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }

        self.domain = domain
        self.email = email
        self.firstName = firstName as String
        self.groupID = groupCode
        self.lastName = lastName as String
        self.userIdentifier = userIdentifier
        self.userName = userName
    }
    
    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> EnrolledUserInformationImpl {

        guard let data = data else {
            throw AWError.SDK.Service.Endpoint.UserInfo.missingResponseData
        }
        
        let jsonResult = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions.mutableContainers)

        guard let jsonDict = jsonResult as? [String: AnyObject] else {
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }

        return try EnrolledUserInformationImpl(jsonDict: jsonDict)
    }
}


public typealias EnrolledUserInformationFetchCompletion = (_ userInfo: EnrolledUserInformation?,_ error: NSError?) -> Void


internal class EnrolledUserInformationFetchEndpoint: DeviceServicesEndpoint {
    
    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
    }

    public func fetchEnrolledUserInformation(completion: @escaping EnrolledUserInformationFetchCompletion) {
        let userInfoEndpoint = UserInfoEndpoint(config: self.config, authorizer: self.authorizer, validator: self.validator)
        userInfoEndpoint.fetchUserInfo{ (fetchedUserInfo, error) in
            guard
                let userID = fetchedUserInfo?.userId, userID > 0
            else {
                completion(nil, error)
                return
            }

            self.fetchUserInfo(userIdentifier: userID, completion: completion)
        }
    }

    private func fetchUserInfo(userIdentifier: Int, completion: @escaping EnrolledUserInformationFetchCompletion) -> Void
    {
        self.serviceEndpoint = "deviceservices/awmdmsdk/v3/users/userid/\(userIdentifier)"
        self.GET { (response: EnrolledUserInformationImpl?, error: NSError?) in
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
}
