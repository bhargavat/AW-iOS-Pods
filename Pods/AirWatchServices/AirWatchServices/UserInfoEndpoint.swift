//
//  UserInfoAPI.swift
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

public final class UserInfoResponse: CTLDataObjectProtocol {
    public fileprivate(set) var userName: String
    public fileprivate(set) var accountType: String
    public fileprivate(set) var isActive: Bool
    public fileprivate(set) var organizationGroup: String
    public fileprivate(set) var userCategory: String
    public fileprivate(set) var userId: NSInteger

    /* Example Response from server:
     {
     AccountType = Basic;
     IsActive = True;
     LocationGroup = TheFunGroup;
     UserCategory = Default;
     UserId = 17426;
     UserName = Funny;
     }
     */

    fileprivate init(jsonDict: [String: AnyObject]) throws {
        /// Validate inputs
        if let userName = jsonDict["UserName"] as? String,
            let accountType = jsonDict["AccountType"] as? String,
            let isActiveNSString = jsonDict["IsActive"] as? NSString,
            let orgGroup = jsonDict["LocationGroup"] as? String,
            let userIdNSString = jsonDict["UserId"] as? NSString,
            let userCat = jsonDict["UserCategory"] as? String {
            self.userName = userName
            self.accountType = accountType
            self.isActive = isActiveNSString.boolValue
            self.organizationGroup = orgGroup
            self.userId = userIdNSString.integerValue
            self.userCategory = userCat
        } else {
            throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
        }
    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> UserInfoResponse {
        guard let data = data else {
            throw AWError.SDK.Service.Endpoint.UserInfo.missingResponseData
        }

        #if DEBUG
        if let dataString = NSString(data: data, encoding:String.Encoding.utf8.rawValue) {
            NSLog("\(dataString)")
        }
        #endif

        let jsonResult = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)

        if let jsonDict = jsonResult as? [String: AnyObject] {
            return try UserInfoResponse(jsonDict: jsonDict)
        }

        throw AWError.SDK.Service.Endpoint.UserInfo.invalidResponseData
    }
}

public typealias UserInfoCompletionHandler = (_ userInfo: UserInfoResponse?, _ error: NSError?) -> Void

/**
 *
 */
internal class UserInfoEndpoint: DeviceServicesEndpoint {

    /**
     * init initializes the UserInfoAPI class using any object that follows the UserInfoConfig Protocol provided
     * Parameters: config - any object that adopts DeviceServicesConfiguration protocol
     * Output: UserInfoAPI object instantiated with the values given from the config object
     */
    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = "deviceservices/awmdmsdk/v1/platform/\(self.config.deviceType)/uid/\(self.config.deviceId)/user"
    }

    /**
     * fetchUserInfo creates and runs a request to the AW server to retrieve the UserInfo
     * Parameters: CompletionHandler - used to allow custom processing of the returned UserInfo data
     * Output: Void
     */
    public func fetchUserInfo(_ completionHandler: @escaping UserInfoCompletionHandler) -> Void {

        self.GET { (response: UserInfoResponse?, error: NSError?) in
            guard error == nil else {
                let userError = self.getUserInfoError(error!) ?? error
                completionHandler(nil, userError)
                return
            }

            guard response != nil else {
                completionHandler(nil, AWError.SDK.Service.General.invalidJSONResponse.error)
                return
            }

            completionHandler(response!, nil)
        }
    }

    fileprivate func getUserInfoError(_ error: NSError) -> NSError? {
        var statusError: AWError.SDK.Service.Endpoint.UserInfo? = nil
        if let httpResponse = error.userInfo[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 404: NSLog("User Info call Received 404")
            statusError =  AWError.SDK.Service.Endpoint.UserInfo.receivedStatusCode404

            case 403: NSLog("User Info call Received 403")
            statusError = AWError.SDK.Service.Endpoint.UserInfo.receivedStatusCode403

            case 401: NSLog("User Info call Received 401")
            statusError = AWError.SDK.Service.Endpoint.UserInfo.receivedStatusCode401

            case 500: NSLog("User Info call Received 500")
            statusError = AWError.SDK.Service.Endpoint.UserInfo.serverError

            case 200: NSLog("User Info call Received 200")
            statusError = AWError.SDK.Service.Endpoint.UserInfo.otherError(error.code)

            default: NSLog("User Info call Received \(httpResponse.statusCode)")
            statusError = AWError.SDK.Service.Endpoint.UserInfo.genericError
            }
        }

        if let statusError = statusError {
            return statusError.error
        }

        return nil
    }

}
