//
//  CTLService.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWError


public typealias CTLServiceRetryBlock = (CTLSessionFetcher, Bool, NSError?) -> Bool

/**
    The Public Client Service API.
 
    This class is the base class to provide basic network access for individual services. The
    underlying fetching is conducted by `CTLSessionFetcher`.

    It sits as an executor to start the network fetching and call the completion handler to
    pass back the result object or error. By subclassing from this class, endpoint service
    APIs can be defined and implemented in a way that the outgoing network request would be
    made via `fetchURL` function or `execute` function. A sample usage is as below:
    ```
        public class TasksService: CTLService {
            public override init() {
                super.init()
                self.serviceURL = NSURL(string:"https://example.com/endpoint")
            }

            public getTasksList(completionHandler: CompletionHandler) {
                let taskUrl = NSURL(string:"\(self.serviceURL.absoluteString)/tasks")
                self.fetchURL(taskUrl,
                              dataToPost: nil,
                              ETag: nil,
                              httpMethod: "GET",
                              mayAuthorize: false,
                              executingQuery:nil) {
                    (rsp: CTLJSONObject?, error: NSError?) in
                    completionHandler(rsp, error)
                }
            }
        }
    ```
 */
open class CTLService : NSObject {
    /**
        Below public properties are not thread safe (except authorizer). It's consumer's responsiblities
        to ensure atomic assess for those properties.
     */
    open var serviceURL: URL?
    open var fetcherKeeper = CTLSessionFetcherKeeper()

    open var retryBlock: CTLServiceRetryBlock? = nil
    open var retryEnabled: Bool = false
    open var maxRetryInterval: TimeInterval = 60

    open var authorizer: CTLAuthorizationProtocol? {
        get {
            return self.fetcherKeeper.authorizer
        }

        set (auth) {
            self.fetcherKeeper.authorizer = auth
            self.fetcherKeeper.authorizer?.fetcherKeeper = self.fetcherKeeper
        }
    }
    
    open var validator: CTLResponseValidationProtocol? {
        get {
            return self.fetcherKeeper.validator
        }
        
        set (val) {
            self.fetcherKeeper.validator = val
        }
    }

    open var urlQueryParameters: Dictionary<String, String>?
    open var additionalHTTPHeaders: Dictionary<String, String>?

    // Default delegate
    open var delegate: CTLServiceDelegate = CTLServiceDelegate()
    

    /**
        Execute a query and return the results.
        Generic function: S has to be inferred via completionHandler or return type from caller.

        - Parameter query: The query object
        - Parameter completionHandler: Callback function

        - Returns: CTLTask object representing the result
     */
    open func execute<S: CTLDataObjectProtocol>(query: CTLQuery, _ completionHandler: @escaping (S?, NSError?) -> Void) -> CTLTask<S>? {

        guard let serviceURL = self.serviceURL else {
            log(error: "Empty service URL")
            completionHandler(nil, AWError.SDK.CoreNetwork.CTL.invalidURL.error)
            return nil
        }
    
        var dataToPost: Data? = nil
        if let queryJSON = query.JSON {
            do {
                try dataToPost = JSONSerialization.data(withJSONObject: queryJSON as NSDictionary,
                                                                        options: JSONSerialization.WritingOptions(rawValue: 0))
            } catch let err as NSError {
                log(debug: "JSON generation error: \(err.localizedDescription)")
                completionHandler(nil, err)
                return nil
            }
        }
    
        let mayAuthorize = !query.shouldSkipAuthorization
        return self.fetchURL(serviceURL,
                             dataToPost: dataToPost,
                             ETag: nil,
                             httpMethod: query.httpMethod,
                             mayAuthorize: mayAuthorize,
                             executingQuery: query,
                             completionHandler)
    }

    /**
        Start a fetch for an URL.

        - Parameter url: The NSURL to fetch
        - Parameter dataToPost: The HTTP Post body
        - Parameter httpMethod: HTTP Method
        - Parameter completionHandler: Callback function

        - Returns: CTLTask object representing the result
     */
    open func fetchURL<S: CTLDataObjectProtocol>(_ url: URL,
                         dataToPost: Data? = nil,
                         httpMethod: String = "GET",
                         completionHandler: @escaping (S?, NSError?) -> Void) -> CTLTask<S>? {
        return fetchURL(url,
                        dataToPost: dataToPost,
                        ETag: nil,
                        httpMethod: httpMethod,
                        mayAuthorize: false,
                        executingQuery: nil,
                        completionHandler)
    }

    /**
        Start a fetch for an URL.

        - Parameter url: The NSURL to fetch
        - Parameter dataToPost: The HTTP Post body
        - Parameter ETag: HTTP ETAG
        - Parameter httpMethod: HTTP Method
        - Parameter mayAuthorize: Flag to indicate this request may require authorization
        - Parameter executingQuery: The query object to start this fetch
        - Parameter completionHandler: Callback function

        - Returns: CTLTask object representing the result
     */
    open func fetchURL<S: CTLDataObjectProtocol>(_ url: URL,
                                            dataToPost: Data?,
                                                  ETag: String? = nil,
                                            httpMethod: String,
                                          mayAuthorize: Bool,
                                        executingQuery: CTLQuery? = nil,
                                   _ completionHandler: @escaping (S?, NSError?) -> Void) -> CTLTask<S>?
    {
        var requestURL = url

        if let query = executingQuery {
            if let fullURL = CTLUtilities.URLWithString(url.absoluteString, queryParameters: query.urlQueryParameters) {
                requestURL = fullURL
            }
        }

        if let urlQueryParameters = self.urlQueryParameters {
            if let fullURL = CTLUtilities.URLWithString(requestURL.absoluteString, queryParameters: urlQueryParameters) {
                requestURL = fullURL
            }
        }

        guard let origRequest = self.requestForURL(requestURL, ETag: ETag, httpMethod: httpMethod, additionalHeaders: executingQuery?.addtionalHTTPHeaders) else {
            log(debug: "Failed to create request for \(url)")
            if let absoluteString = url.absoluteString as String? {
                completionHandler(nil, AWError.SDK.CoreNetwork.CTL.createRequestFailure(absoluteString).error)
            }
            return nil
        }

        origRequest.httpBody = dataToPost

        var urlRequest = origRequest.copy() as! URLRequest

        /// Check wheather we're clear to go
        if let shouldForwardRequest = self.delegate.shouldForwardRequest {
            urlRequest = shouldForwardRequest(self, urlRequest)
        }

        if let shouldSendRquest = self.delegate.shouldSendRequest {
            if !shouldSendRquest(self, urlRequest) {
                return nil
            }
        }

        let fetcher = self.fetcherKeeper.fetcherWithRequest(urlRequest)
        if let executingQuery = executingQuery {
            fetcher.taskPriority = executingQuery.priority
        }

        fetcher.retryEnabled = self.retryEnabled

        fetcher.retryBlock = { [weak self, weak fetcher] (suggestedWillRetry: Bool, error: NSError?, response: CTLSessionFetcherRetryResponse) in
            guard let weakSelf = self, let weakFetcher = fetcher else {
                response(false)
                return
            }

            let shouldRetry = weakSelf.shouldFetcher(weakFetcher, willRetry: suggestedWillRetry, forError: error)
            response(shouldRetry)
        }

        if let willSendRequest = self.delegate.willSendRequest {
            willSendRequest(self, urlRequest)
        }

        let task = fetcher.beginFetch(on: nil, mayAuthorize: mayAuthorize, completionHandler)

        if let didSendRequest = self.delegate.didSendRequest {
            didSendRequest(self, urlRequest)
        }

        return task
    }

    open func requestForURL(_ url: URL,
                             ETag: String?,
                       httpMethod: String,
                additionalHeaders: Dictionary<String, String>?) -> NSMutableURLRequest? {
        let request = NSMutableURLRequest(url: url)

        request.httpMethod = httpMethod

        let _ = additionalHeaders?.map() {
            request.setValue($0.1, forHTTPHeaderField: $0.0)
        }

        let _ = additionalHTTPHeaders?.map() {
            request.setValue($0.1, forHTTPHeaderField: $0.0)
        }
    
        /// Set default content type and accept type
        if (request.value(forHTTPHeaderField: "Content-Type") == nil) {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        if (request.value(forHTTPHeaderField: "Accept") == nil) {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        }
        if (request.value(forHTTPHeaderField: "cache-control") == nil) {
            request.setValue("no-cache", forHTTPHeaderField: "cache-control")
        }

        return request
    }

    //MARK: Retry
    fileprivate func shouldFetcher(_ fetcher: CTLSessionFetcher, willRetry: Bool, forError: NSError?) -> Bool {

        var maybeRetry = willRetry
        if let retryBlock = self.retryBlock {
            maybeRetry = retryBlock(fetcher, maybeRetry, forError)
        }

        return maybeRetry
    }
}
