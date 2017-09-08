//
//  ProfileManagerEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWNetwork
import AWError


extension AWServices {

    public enum ConfigurationProfileType: Int {
        case unknown            = 0
        case agent              = 5
        case browser            = 7
        case contentLocker      = 9
        case sharedDevice       = 13
        case sdk                = 21
        case sdkAppWrapping     = 22
        case email              = 18
        case boxer              = 32
    }
}

//public typealias FetchProfileCompletion = (_ profile: Profile?, _ error: NSError?) -> Void

public typealias FetchProfileCompletion = (_ profileInfo: Data?, _ error: NSError?) -> Void

class ProfileManagerEndpoint: DeviceServicesEndpoint {
    let settingsPath: String = "DeviceServices/iOS/SettingsEndpoint.aspx"
    let kSettingsEndpointType = "settingsEndPoint"    /** setting end point type */

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = settingsPath
    }

    func fetchConfigurationProfile(type: AWServices.ConfigurationProfileType, completionHandler: @escaping FetchProfileCompletion) -> Void {
        let queryParameters = self.queryParameterForConfigurationSettings(type)
        guard let endpointURL = self.endPointURLWithQueryParameters(queryParameters) else {
            log(error: "Error Fetching Profile: Invalid URL String")
            completionHandler(nil, AWError.SDK.Service.General.invalidHTTPURL("\(self.hostUrlString), \(self.serviceEndpoint)").error)
            return
        }

        guard type != AWServices.ConfigurationProfileType.unknown else {
            log(error: "Error Fetching Profile: Unknown Configuration Profile Type")
            completionHandler(nil, AWError.SDK.Service.Endpoint.ProfileManager.unknownConfigurationProfile.error)
            return
        }

        self.additionalHTTPHeaders = ["Content-Type": "text/html"]

        log(debug: "Sending GET Request to Fetch Profile Payloads \(type.rawValue)")
        self.GET(endpointURL) { (rsp: Data?, error: NSError?) in
            guard error == nil else {
                log(error: "Profile Fetching GET request returned with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            guard let response = rsp else {
                completionHandler(nil, AWError.SDK.Service.General.unexpectedResponse.error)
                return
            }

            log(debug: "Retreved profile for type: \(String(reflecting: type)): \(String(data: response, encoding: .utf8) ?? "" )) from response data")
            completionHandler(response, nil)
        }
    }

    //MARK:- Private
    fileprivate func queryParameterForConfigurationSettings(_ configurationProfileType: AWServices.ConfigurationProfileType) -> [String: String] {
        var queryParameters: [String: String] = [:]
        queryParameters["bundleid"] = self.config.bundleId
        queryParameters["configtypeid"] = "\(configurationProfileType.rawValue)"
        queryParameters["uid"] = self.config.deviceId
        queryParameters["deviceType"] = self.config.deviceType

        if self.config.organizationGroup.characters.count > 0 {
            queryParameters["groupid"] = self.config.organizationGroup
        }
        return queryParameters
    }

    override internal func requestForURL(_ url: URL,
                                         ETag: String?,
                                         httpMethod: String,
                                         additionalHeaders: [String: String]?) -> NSMutableURLRequest? {
        let request = super.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: additionalHeaders)
        request?.requestType = self.kSettingsEndpointType
        return request
    }
}
