//
//  SecureChannelEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import AWCrypto
import AWCMWrapper
import Foundation


internal extension NSMutableURLRequest {
    internal var requestType: String? {
        get {
            return URLProtocol.property(forKey: SecureChannelConstants.kSecureChannelRequestType, in: self as URLRequest) as? String
        }

        set (type) {
            if (type != nil) {
                URLProtocol.setProperty(type as AnyObject, forKey: SecureChannelConstants.kSecureChannelRequestType, in: self)
            } else {
                URLProtocol.removeProperty(forKey: SecureChannelConstants.kSecureChannelRequestType, in: self)
            }
        }
    }
}


internal final class SecureChannelDataObject: CTLObject, CTLDataObjectProtocol {
    internal fileprivate(set) var decryptedData: Data? = nil

    internal class func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) -> SecureChannelDataObject {

        let scDataObj = SecureChannelDataObject()

        if let fetcher = additionalProperties?[CTLConstants.kCTLDataObjectFetcher] as? CTLSessionFetcher,
            let authorizer = fetcher.authorizer as? SecureChannelAuthorizer,
            let request = additionalProperties?[CTLConstants.kCTLDataObjectURLRequest] as? NSMutableURLRequest,
            let data = data {
            scDataObj.decryptedData = authorizer.decryptAndVerifySignature(request: request, payload: data)
        }

        scDataObj.properties = additionalProperties
        return scDataObj
    }
}


internal class SecureChannelEndpoint: DeviceServicesEndpoint {
    /// The type is meant to be understood by SecureChannel server only
    var channelType = ""

    internal required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol? = nil) {
        assert(authorizer is SecureChannelAuthorizer)
        super.init(config: config, authorizer: authorizer, validator: validator)
    }

    convenience init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol, validator: CTLResponseValidationProtocol? = nil, channelType: String) {
        self.init(config: config, authorizer: authorizer, validator: validator)
        self.channelType = channelType
    }


    func sendSecureData(_ data: Data?, url: NSURL?,
                        completionHandler: @escaping (_ rsp: Data?, _ error: NSError?) -> Void) -> CTLTask<SecureChannelDataObject>? {
        guard let data = data, let url = url else {
            return nil
        }

        return super.fetchURL(url as URL, dataToPost: data, ETag: nil, httpMethod: "POST", mayAuthorize: true, executingQuery: nil) { (rsp: SecureChannelDataObject?, error: NSError?) in
            guard let obj = rsp else {
                completionHandler(nil, error)
                return
            }
            completionHandler(obj.decryptedData, nil)
        }
    }

    typealias FetchURLCompletionHandler<T: CTLDataObjectProtocol> =  (_ rsp: T?, _ error: NSError?) -> Void

    override func fetchURL<T: CTLDataObjectProtocol>(
        _ url: URL,
        dataToPost: Data?,
        ETag: String?,
        httpMethod: String,
        mayAuthorize: Bool,
        executingQuery: CTLQuery?,
        _ completionHandler: @escaping FetchURLCompletionHandler<T>) -> CTLTask<T>? {

        let shellTask = CTLTask<T>()
        func shouldRecheckIn(_ secureChannelResponse: SecureChannelDataObject) -> Bool {

            let properties = secureChannelResponse.properties
            guard let httpResponse = properties?[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse else {
                return false
            }

            if httpResponse.statusCode == 412 {
                return true
            }

            /**
             XXX: Server might return 200 status OK with plain JSON format body
             data which contains status code 412 inside. Client expects
             nil decrypted data in this case since response data is not
             encrypted.
             */
            if secureChannelResponse.decryptedData == nil,
                httpResponse.statusCode == 200,
                let responseData = properties?[CTLConstants.kCTLDataObjectURLResponseData] as? Data,
                let json = try? CTLJSONObject.objectWithData(responseData, additionalProperties:nil),
                let dict = json.JSON as? NSDictionary,
                let root = dict["d"] as? NSDictionary,
                let statusCode = root["Status"] as? Int , statusCode == 412 {
                return true
            }

            return false
        }


        func processResponse<T: CTLDataObjectProtocol>(_ rsp: SecureChannelDataObject?, _ error: NSError?, completingTask: CTLTask<T>, recheckIn: ((Void) -> Void)?,  completionHandler: @escaping FetchURLCompletionHandler<T>) {

            guard let secureChannelResponse = rsp else {
                completionHandler(nil, error)
                return
            }

            /// Re-checkin if seeing 412 response
            if let secureChannelResponse = rsp, shouldRecheckIn(secureChannelResponse), let checkinBlock = recheckIn {
                checkinBlock()
                return
            }

            var err = error
            do {
                var rspObject: T = try T.objectWithData(secureChannelResponse.decryptedData, additionalProperties: secureChannelResponse.properties)
                completingTask.completeWithValue(rspObject)
                completionHandler(rspObject, err)
            } catch let e as NSError {
                let localizedDescription = e.userInfo[NSLocalizedDescriptionKey]
                var properties = secureChannelResponse.properties
                properties?[NSLocalizedDescriptionKey] = localizedDescription as AnyObject
                err = NSError(domain: e.domain, code: e.code, userInfo: properties)
                completionHandler(nil, err)
            }
        }

        let recheckIn = {
            log(info: "Server requires secure channel re-checkin!")

            let scAuthorizer = self.authorizer as! SecureChannelAuthorizer
            scAuthorizer.configurationManager.clearAll()

            _ = super.fetchURL(url, dataToPost: dataToPost, ETag:ETag, httpMethod:httpMethod, mayAuthorize:mayAuthorize, executingQuery:executingQuery) {
                (rsp: SecureChannelDataObject?, error: NSError?) in
                processResponse(rsp, error, completingTask: shellTask, recheckIn: nil, completionHandler: completionHandler)
            }
        }

        let task = super.fetchURL(url, dataToPost: dataToPost, ETag: ETag, httpMethod: httpMethod, mayAuthorize: mayAuthorize, executingQuery: executingQuery) { (rsp, error) in
            processResponse(rsp, error, completingTask: shellTask, recheckIn: recheckIn , completionHandler: completionHandler)
        }

        return task != nil ? shellTask : nil
    }

    override internal func requestForURL(_ url: URL,
                                         ETag: String?,
                                         httpMethod: String,
                                         additionalHeaders: [String: String]?) -> NSMutableURLRequest? {
        if let request = super.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: additionalHeaders) {
            request.requestType = channelType
            request.setValue("no-cache", forHTTPHeaderField: "cache-control")
            return request
        } else {
            return nil
        }
    }
}
