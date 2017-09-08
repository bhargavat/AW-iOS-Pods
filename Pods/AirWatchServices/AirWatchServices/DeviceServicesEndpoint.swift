//
//  DeviceServicesEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWNetwork

internal class DeviceServicesEndpoint: CTLService {

    public fileprivate(set) var config: DeviceServicesConfiguration

    /**
        A surrogate endpoint is meant to route all fetchings to that endpoint so that custom transmission
        protocol can be implemented inside proxy endpoint. An example of this is assign this with
        `SecureChannelEndpoint` so that fetchings are made on top of secure channel protocol.
     */
    internal var surrogate: DeviceServicesEndpoint? = nil

    internal var hostUrlString: String { return config.airWatchServerURL }
    internal var serviceEndpoint: String = ""

    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        self.config = config
        super.init()
        self.authorizer = authorizer
        self.validator = validator
    }

    override public func fetchURL<T: CTLDataObjectProtocol>( _ url: URL, dataToPost: Data?, ETag: String?, httpMethod: String, mayAuthorize: Bool, executingQuery: CTLQuery?,
        _ completionHandler: @escaping (_ rsp: T?, _ error: NSError?) -> Void) -> CTLTask<T>? {

        guard let surrogate = self.surrogate else {
            return super.fetchURL(url,
                                  dataToPost: dataToPost,
                                  ETag: ETag,
                                  httpMethod: httpMethod,
                                  mayAuthorize: mayAuthorize,
                                  executingQuery: executingQuery,
                                  completionHandler)
        }

        surrogate.delegate.shouldForwardRequest = {[weak self] (service: CTLService, request: URLRequest) -> URLRequest in
            /// Use original request

            guard let weakSelf = self else { return request }

            let forwardRequest = weakSelf.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: executingQuery?.addtionalHTTPHeaders)
            if let origRequest = forwardRequest, var urlRequest = origRequest as? URLRequest {
                origRequest.httpBody = dataToPost
                return urlRequest
            }

            return request
        }

        let task =  surrogate.fetchURL(url, dataToPost: dataToPost, ETag: ETag, httpMethod: httpMethod, mayAuthorize: mayAuthorize, executingQuery: executingQuery, completionHandler)
        /// Reset the forwarding
        surrogate.delegate.shouldForwardRequest = nil
        return task
    }
}

extension DeviceServicesEndpoint: RestfulServiceEndPoint { }
