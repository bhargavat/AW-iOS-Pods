//
//  RestfulServiceEndPoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork

private enum HTTPMethod: String {
    case GET    = "GET"
    case POST   = "POST"
    case PUT    = "PUT"
    case DELETE = "DELETE"
    case HEAD   = "HEAD"
}

protocol EndPointURLProvider {
    var hostUrlString: String { get }
    var serviceEndpoint: String { get }

    var endpointURL: URL? { get }
    func endPointURLWithQueryParameters(_ queryParameters: [String: String]) -> URL?
}

extension EndPointURLProvider {

    var endpointURL: URL? {
        let hostUrl = hostUrlString

        guard hostUrl.characters.count > 0 else {
            return nil
        }

        let hostname:String = hostUrl.hasSuffix("/") ? String(hostUrl.characters.dropLast()) : hostUrl

        if serviceEndpoint.characters.count > 0 {
            let endpointPath = serviceEndpoint.hasPrefix("/") ? String(serviceEndpoint.characters.dropFirst()) : serviceEndpoint
            guard let url = URL(string: "\(hostname)/\(endpointPath)") else {
                log(error: "Can not Construct URL: \(hostname) EndPoint: \(endpointPath)")
                return nil
            }
            return url
        }

        return URL(string: hostname)
    }

    func endPointURLWithQueryParameters(_ queryParameters: [String: String]) -> URL? {
        guard let currentURL = self.endpointURL else {
            log(error: "Error constructing URL")
            return nil
        }

        guard let urlComponentTmp = URLComponents(url: currentURL, resolvingAgainstBaseURL: false) else {
            log(error: "Error constructing URL Components from URL: \(self.endpointURL.debugDescription)")
            return nil
        }
        var urlComponent: URLComponents = urlComponentTmp
        var queryItems = urlComponent.queryItems ?? []
        queryItems.append(contentsOf: queryParameters.map { URLQueryItem(name: $0, value: $1)})

        if queryItems.count > 0 {
            urlComponent.queryItems = Array(Set<URLQueryItem>(queryItems)).sorted() {$0.name < $1.name}
        }

        return urlComponent.url
    }


}
protocol RestfulServiceEndPoint: EndPointURLProvider {
    func POST<S: CTLDataObjectProtocol>(_ url: URL, data: Data?, completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void )
    func GET<S: CTLDataObjectProtocol>(_ url: URL, completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void )

    func POST<S: CTLDataObjectProtocol>(_ data: Data?, completionHandler: @escaping(_ rsp: S?, _ error: NSError?) -> Void )
    func GET<S: CTLDataObjectProtocol>(_ completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void )
}

extension RestfulServiceEndPoint where Self: CTLService {

    func POST<S: CTLDataObjectProtocol>(_ url: URL, data: Data?, completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void ) {
        _ = self.fetchURL(url,
                      dataToPost: data,
                      ETag: nil,
                      httpMethod: HTTPMethod.POST.rawValue,
                      mayAuthorize: true,
                      executingQuery: nil, completionHandler)

    }

    func GET<S: CTLDataObjectProtocol>(_ url: URL, completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void ) {
        _ = self.fetchURL(url,
                      dataToPost: nil,
                      ETag: nil,
                      httpMethod: HTTPMethod.GET.rawValue,
                      mayAuthorize: true,
                      executingQuery: nil, completionHandler)
    }

    func POST<S: CTLDataObjectProtocol>(_ data: Data?, completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void ) {
        assert(self.endpointURL != nil, "Can not post without URL")
        _ = self.fetchURL(self.endpointURL!,
                      dataToPost: data,
                      ETag: nil,
                      httpMethod: HTTPMethod.POST.rawValue,
                      mayAuthorize: true,
                      executingQuery: nil, completionHandler)
    }

    func GET<S: CTLDataObjectProtocol>(_ completionHandler: @escaping (_ rsp: S?, _ error: NSError?) -> Void ) {
        assert(self.endpointURL != nil, "Can not get without URL")
        _ = self.fetchURL(self.endpointURL!,
                      dataToPost: nil,
                      ETag: nil,
                      httpMethod: HTTPMethod.GET.rawValue,
                      mayAuthorize: true,
                      executingQuery: nil, completionHandler)
    }
}
