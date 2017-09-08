//
//  TermsOfUseEndpoint.swift
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

extension AWServices {
    public enum EULAAcceptanceStatus: Int {
        case accepted
        case notAccepted
        case unknown
    }
}

internal class EULAAcceptanceStatusEndpoint: DeviceServicesEndpoint {

    private static let kIsEulaAcceptanceRequired = "IsEulaAcceptanceRequired"

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = "/deviceservices/awmdmsdk/v1/platform/2/uid/\(self.config.deviceId)/eula"
    }

    internal func getAcceptanceStatus(completion: @escaping (_ requiredEULAAcceptance: AWServices.EULAAcceptanceStatus, _ error: NSError?) -> Void) {
        self.serviceEndpoint.append("/checkeula/appid/\(self.config.bundleId)")
        self.GET { (response: CTLJSONObject?, error: NSError?) in
            if let error = error {
                completion(.unknown, error)
                return
            }

            guard let response = response, let jsonObject = response.JSON as? [String: AnyObject] else {
                completion(.unknown, AWError.SDK.Service.General.invalidJSONResponse.error as NSError)
                return
            }

            guard let eulaAcceptanceRequired = jsonObject[EULAAcceptanceStatusEndpoint.kIsEulaAcceptanceRequired] as? Bool else {
                completion(.unknown, AWError.SDK.Service.General.unexpectedResponse.error as NSError)
                return
            }

            if eulaAcceptanceRequired {
                completion(AWServices.EULAAcceptanceStatus.notAccepted, nil)
            } else {
                completion(AWServices.EULAAcceptanceStatus.accepted, nil)
            }
        }
    }

    internal func updateEULAAcceptance(contentID: UInt, status: AWServices.EULAAcceptanceStatus, completion: @escaping (Bool, NSError?)-> Void) {
        switch status {
        case .unknown:
            log(error: "Can not update unknown status to server")
            completion(false, AWError.SDK.Service.Authorization.invalidInputs.error)
            return

        case .accepted:
            self.serviceEndpoint.append("/accepteula")

        case .notAccepted:
            self.serviceEndpoint.append("/rejecteula")
        }

        let requestBodyDict = [AWServices.EULAContent.kAWTOUContentId: contentID]
        let requestBodyData = try? JSONSerialization.data(withJSONObject: requestBodyDict, options: [])
        self.POST(requestBodyData) { (json: CTLJSONObject?, error: NSError?) in
            if let error = error {
                completion(false, error)
                return
            }

            guard let urlResponse = json?.properties?[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse else {
                completion(false, AWError.SDK.Service.General.unexpectedResponse.error)
                return
            }

            completion(urlResponse.statusCode == 200, error)
        }

    }
}

extension AWServices {

    public final class EULAContent: CTLDataObjectProtocol {
        let contentID: UInt
        let content: String
        let applicationList: [String]

        private init(contentID: UInt, content: String, applicationList: [String]) {
            self.contentID = contentID
            self.content = content
            self.applicationList = applicationList
        }

        static let kAWTOUContentId       = "EulaContentId"
        static let kAWTOUContent         = "EulaContent"
        static let kAWTOUApplicationList = "ApplicationList"

        public static func objectWithData(_ data: Data?, additionalProperties: Dictionary<String, AnyObject>?) throws -> EULAContent {
            guard let data = data else {
                throw AWError.SDK.Service.General.invalidJSONResponse
            }

            guard
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
                let contentID = jsonObject[AWServices.EULAContent.kAWTOUContentId] as? UInt,
                let content = jsonObject[AWServices.EULAContent.kAWTOUContent] as? String else {
                    throw AWError.SDK.Service.General.unexpectedResponse
            }

            let applicationList = jsonObject[AWServices.EULAContent.kAWTOUApplicationList] as? [String] ?? []
            return EULAContent(contentID: contentID, content: content, applicationList: applicationList)
        }
    }
}

internal class EULAContentFetchEndpoint: DeviceServicesEndpoint {

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = "/deviceservices/awmdmsdk/v1/platform/2/uid/\(self.config.deviceId)/eula/fetcheula/appid/\(self.config.bundleId)"
    }

    internal func fetchEULAContent(contentID: Int = -1, completion: @escaping (_ content: AWServices.EULAContent?, NSError?) -> Void) {
        if contentID >= 0 {
            self.serviceEndpoint.append("/eulacontentid/\(contentID)")
        }

        self.GET { (content: AWServices.EULAContent?, error: NSError?) in
            completion(content, error)
        }
    }
}
