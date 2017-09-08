//
//  CTLFetcher.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import Alamofire

import AWCrypto
import AWError

public typealias CTLSessionFetcherRetryResponse = (Bool) -> Void
public typealias CTLSessionFetcherRetryBlock = (Bool, NSError?, CTLSessionFetcherRetryResponse) -> Void

extension URLRequest {

    var detailedDescription: String {
        let url = self.url?.absoluteString ?? "none"
        let method = self.httpMethod ?? "none"
        let timeout = self.timeoutInterval
        let headers = self.allHTTPHeaderFields?.map{return "\($0): \($1), "}.reduce("", +) ?? "None"
        let contentSize = self.httpBody?.count ?? 0
        return "\n\n" +
               "\n          URL: \(url)" +
               "\n       Method: \(method)" +
               "\n      Timeout: \(timeout)" +
               "\n      Headers: [\(headers)]" +
               "\n Content Size: \(contentSize)" +
               "\n\n"
    }
}

extension DefaultDataResponse {

    var detailedDescription: String {

        let url = self.response?.url?.absoluteString ?? "none"
        let status = self.response?.statusCode ?? -1
        let headers = self.response?.allHeaderFields.map{return "\($0): \($1),"}.reduce("", +) ?? "None"
        let contentSize = self.data?.count ?? 0
        let error = self.error
        return
            "\n\n" +
            "\n          URL: \(url)" +
            "\n  HTTP Status: \(status)" +
            "\n      Headers: [\(headers)]" +
            "\n Content Size: \(contentSize)" +
            "\n        Error: \(String(describing: error))" +
            "\n\n"
    }
}

/**
    CTLSessionFetcher is the class to perform actual networking activities, via Alamofire.
    It is thread safe and right now, one fetcher can only be used per one request. Although
    it can safely perform multiple fetches for the same request concurrently, the behavior is undefined
    and is not recommened. The underlying retrying machanism should be ultilized instead.
 */
open class CTLSessionFetcher: NSObject {

    /**
        `sharedSessionDelegate` is solely used to handle session callbacks globally. It shouldn't be used
        in place where local handler would otherwise be consulted. Caller should ensure the synchronization
        or thread safety when setting this property

        `sharedSessionDelegate` is always being consulted prior to local fetcher specific `sessionDelegate`.
     */
    open static var sharedSessionDelegate: CTLSessionDelegateProtocol = CTLSessionDelegate()

    /// To force check of auth flag when fetching if set to false
    open var ignoreAuthFlag: Bool = true

    internal var serviceHost: String? = nil

    fileprivate var _callbackQueue = DispatchQueue.main

    fileprivate static var _sharedAlamofireManager: SessionManager = CTLSessionFetcher.defaultAlamofireManager()
    fileprivate var alamofireManager = CTLSessionFetcher.sharedAlamofireManager

    fileprivate var _authorizer: CTLAuthorizationProtocol? = nil
    fileprivate var _responseValidator: CTLResponseValidationProtocol? = nil

    fileprivate var _taskPriority: UInt = 0

    fileprivate var _retryEnabled: Bool = false

    fileprivate var _retryBlock: CTLSessionFetcherRetryBlock? = nil

    fileprivate var _retryCount: UInt = 0
    fileprivate var _maxRetryCount: UInt = 3

    fileprivate weak var _keeper: CTLSessionFetcherKeeper? = nil

    fileprivate(set) var mutableRequest: NSMutableURLRequest? = nil
    
    open var currentRequest: URLRequest? {
        get {
            let copy = mutableRequest?.copy() as? URLRequest
            return copy
        }
    }

    fileprivate var _underlyingRequest: Request? = nil

    fileprivate var _sessionDelegate: CTLSessionDelegateProtocol = CTLSessionDelegate()

    public init(request: URLRequest? = nil, configuration: URLSessionConfiguration? = nil) {

        super.init()

        if let request = request {
            mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest
        }

        if let configuration = configuration {
            alamofireManager = Alamofire.SessionManager(configuration: configuration, delegate: AWCTLSessionDelegate(), serverTrustPolicyManager: nil)
        }

        alamofireManager.startRequestsImmediately = false

        registerAlamofireCallbacks()
    }

    open class func fetcherWithRequest(_ urlRequest: URLRequest) -> CTLSessionFetcher {
        return CTLSessionFetcher.fetcherWithRequest(urlRequest, configuration: nil)
    }

    open class func fetcherWithRequest(_ urlRequest: URLRequest, configuration: URLSessionConfiguration?) -> CTLSessionFetcher {
        return CTLSessionFetcher(request: urlRequest, configuration: configuration)
    }

    open func beginFetch<S: CTLDataObjectProtocol> (on: DispatchQueue?,
                         mayAuthorize: Bool,
                         _ completionHandler: @escaping (S?, NSError?) -> Void) -> CTLTask<S>? {

        guard let currentMutableRequest = self.mutableRequest else {
            log(debug: "No request to fetch!")
            callbackQueue.async {
                completionHandler(nil, AWError.SDK.CoreNetwork.CTL.invalidURL.error)
            }
            return nil
        }

        var shouldAuthorize = mayAuthorize
        if self.ignoreAuthFlag {
            shouldAuthorize = (self.authorizer != nil)
        } else if shouldAuthorize && self.authorizer == nil {
            log(error: "Authorization is required but no authorizer can be found!")
            callbackQueue.async {
                completionHandler(nil, AWError.SDK.CoreNetwork.CTL.invalidAuthorizer.error)
            }
            return nil
        }
        
        if let keeper = self.keeper , keeper.fetcherShouldBeginFetching(self) == false {
            log(debug: "Fetching can not be started")
            callbackQueue.async {
                completionHandler(nil, AWError.SDK.CoreNetwork.CTL.startFetchingFailure.error)
            }
            return nil
        }

        let shellTask = CTLTask<S>()
        
        shellTask.fetcher = self
        
        let workerQueue = on ?? CTLSessionFetcherKeeper.getFetchQueue(priority: self.taskPriority)

        /// authorize the request if necessary
        if shouldAuthorize {
            if let authTask = self.authorizer?.authorize(request: currentMutableRequest, on: workerQueue) {
                _=authTask.then {
                    /// At this point, the request is signed and authorized.
                    return Task<Void>.performWork(on: workerQueue) {
                        self.fetchRequest(currentMutableRequest as URLRequest, callbackQueue: workerQueue, task: shellTask)
                    }
                }.addErrorCallback(on: workerQueue) { (err: NSError?) in
                    shellTask.failWithError(err)
                }
            } else {
                shellTask.failWithError(AWError.SDK.CoreNetwork.CTL.requestAuthorizationNotStarted.error)
            }
        } else {
            _=Task<Void>.performWork(on: workerQueue) {
                self.fetchRequest(currentMutableRequest as URLRequest, callbackQueue: workerQueue, task: shellTask)
            }
        }

        return shellTask
            .addCallback(on: callbackQueue) { (rsp: S) in
                completionHandler(rsp, nil)
                self.keeper?.fetcherDidStop(self)
            }
            .addErrorCallback(on: callbackQueue) { (err: NSError?) in

                let finishWithError = { (shouldRetry: Bool) in

                    guard shouldRetry else {
                        let dataObject = err?.userInfo["cf76016272d201324da998579288b6a6" as NSObject] as? S
                        completionHandler(dataObject, err)
                        self.keeper?.fetcherDidStop(self)
                        return
                    }

                    /// Always start retrying on main thread
                    DispatchQueue.main.async {
                        self.retryCount += 1
                        _=self.beginFetch(on: on, mayAuthorize: shouldAuthorize, completionHandler)
                    }
                }

                /// Check retry status
                guard let urlResponse = err?.urlResponse else {
                    self.shouldRetryNow(status: -1, error: err) { (shouldRetry) in
                        finishWithError(shouldRetry)
                    }
                    return
                }

                /// Check whether we need to refresh authorization
                guard var authorizer = self.authorizer, (shouldAuthorize && urlResponse.statusCode == 403) else {
                    self.shouldRetryNow(status: urlResponse.statusCode, error: err) { (shouldRetry) in
                        finishWithError(shouldRetry)
                    }
                    return
                }
                
                authorizer.refreshAuthorization { (refreshedAuthorizer: CTLAuthorizationProtocol?, error: NSError?) in
                    guard let refreshedAuthorizer = refreshedAuthorizer else {
                        if let error = error {
                            log(error: "Error on refreshing authorization token: \(error.localizedDescription)")
                        }
                        /// Continue from where it's before refreshing
                        self.shouldRetryNow(status: urlResponse.statusCode, error: err) { (shouldRetry) in
                            finishWithError(shouldRetry)
                        }
                        return
                    }
            
                    /// Start a fresh request with refreshed authorizer if possible
                    guard let fetcher = refreshedAuthorizer.fetcherKeeper?.fetcherWithRequest(currentMutableRequest as URLRequest) else {
                        self.authorizer = refreshedAuthorizer
                        _ = self.beginFetch(on: on, mayAuthorize: shouldAuthorize, completionHandler)
                        return
                    }
            
                    fetcher.ignoreAuthFlag = self.ignoreAuthFlag
                    _=fetcher.beginFetch(on: on, mayAuthorize: shouldAuthorize, completionHandler)
                }
        }
    }

    open func stopFetch() {
        if let req = self.underlyingRequest {
            req.cancel()
        }
    }

    open class func resetSessionManager() {
        CTLSessionFetcher.sharedAlamofireManager = CTLSessionFetcher.defaultAlamofireManager()
    }

    fileprivate class func defaultAlamofireManager() -> SessionManager {
        let conf = URLSessionConfiguration.default
        conf.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        return Alamofire.SessionManager(configuration: conf, delegate: AWCTLSessionDelegate(), serverTrustPolicyManager: nil)
    }


    fileprivate func fetchRequest<S: CTLDataObjectProtocol>(_ request: URLRequest, callbackQueue: DispatchQueue, task: CTLTask<S>) {
        log(verbose: "Request: \(request.detailedDescription)")

        if let body = request.httpBody, body.count <= 1024 {
            log(debug: "Request Body: \(body.base64EncodedString())")
        } else if request.httpBody != nil {
            log(debug: "Request Body: Won't print as it is larger than 1KB")
        } else {
            log(debug: "Request Body: none")
        }
        
        self.underlyingRequest = self.alamofireManager.request(request).response(queue: callbackQueue) { (dataResponse) in

            let urlRequest: URLRequest? = dataResponse.request
            let rsp: HTTPURLResponse? = dataResponse.response
            let data: Data? = dataResponse.data
            let err: NSError? = dataResponse.error as NSError?
            log(verbose: "Response: \(dataResponse.detailedDescription)")

            if let responseData =  dataResponse.data, responseData.count <= 1024 {
                log(debug: "Response Body: \(responseData.base64EncodedString())")
            } else if dataResponse.data != nil {
                log(debug: "Response Body: Won't print as it is larger than 1KB")
            } else {
                log(debug: "Response Body: none")
            }

            guard let req = urlRequest else {
                task.failWithError(AWError.SDK.CoreNetwork.CTL.httpStatus(-1, "Missing Request").error)
                fatalError("Trying to run a network task without proper URL Request. Will fail")
            }

            var additionalProperties: [AnyHashable: Any] = [CTLConstants.kCTLDataObjectURLRequest: req, CTLConstants.kCTLDataObjectFetcher: self]

            if (rsp != nil) {
                additionalProperties[CTLConstants.kCTLDataObjectURLResponse] = rsp
            }

            if (data != nil) {
                additionalProperties[CTLConstants.kCTLDataObjectURLResponseData] = data
            }

            @inline(__always)
            func mergeDict ( _ left: inout [AnyHashable: Any], with: [AnyHashable: Any]) {
                for (k, v) in with {
                    left.updateValue(v, forKey: k)
                }
            }


            //If the request is errored out
            if let errror = err {
                mergeDict(&additionalProperties, with: (errror.userInfo))
                task.failWithError(NSError(domain: errror.domain, code: errror.code, userInfo: additionalProperties))
                return
            } else if let response = rsp {
                /// Catch general HTTP status error
                var httpErr: NSError? = nil
                if response.statusCode >= 400 {
                    let err = AWError.SDK.CoreNetwork.CTL.httpStatus(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
                    if let userInfo = err.userInfo {
                        mergeDict(&additionalProperties, with: userInfo)
                    }
                    httpErr = err.error
                }

                // This block will capture the httpErr, task, data, additionalProperties.
                self.validateResponse(rsp, responseData: data) {(validationError: NSError?) in

                    if let validationError = validationError {
                        // Response validation failed. So we will override the actual error with validation failure error.
                        mergeDict(&additionalProperties, with: validationError.userInfo)
                        task.failWithError(NSError(domain: validationError.domain, code: validationError.code, userInfo: additionalProperties))
                        return
                    }
                    // Validation passed, get back to business.
                    do {
                        let result = try S.objectWithData(data, additionalProperties: additionalProperties as? Dictionary<String, AnyObject>)
                        if let httpErr = httpErr {
                            /// Pass both httpErr and result back (Task doesn't support both)
                            additionalProperties["cf76016272d201324da998579288b6a6"/*MD5("CTLObject")*/] = result
                            task.failWithError(NSError(domain: httpErr.domain, code: httpErr.code, userInfo: additionalProperties))
                        } else {
                            task.completeWithValue(result)
                        }
                    } catch let err {
                        let nsError = (err as? AWErrorType)?.error ?? (err as? NSError) ?? NSError()
                        mergeDict(&additionalProperties, with: nsError.userInfo)
                        task.failWithError(NSError(domain: nsError.domain, code: nsError.code, userInfo: additionalProperties))
                    }
                }
            } else {
                //This should never happen according to William Hooper!
                task.failWithError(AWError.SDK.CoreNetwork.CTL.httpStatus(-1, "Unknown Error").error)
            }
        }

        self.underlyingRequest?.resume()
    }

    fileprivate func validateResponse(_ response: HTTPURLResponse?, responseData: Data?, completion:(NSError?) -> Void) {

        guard let validator = self._responseValidator else {
            log(debug: "No Validator is associated with the current request. Validation Successful.")
            completion(nil)
            return
        }
        
        validator.validateResponse(response, responseData: responseData, completion: completion)
    }

}

/**
    Properties
 */
public extension CTLSessionFetcher {
    public var callbackQueue: DispatchQueue {
        set(queue) {
            CTLSynchronizer.synchronized {
                self._callbackQueue = queue
            }
        }
        get {
            var q: DispatchQueue? = nil
            CTLSynchronizer.synchronized {
                q = self._callbackQueue
            }
            return q!
        }
    }

    public var taskPriority: UInt {
        set(priority) {
            CTLSynchronizer.synchronized {
                self._taskPriority = priority
            }
        }
        get {
            var ret: UInt = 0
            CTLSynchronizer.synchronized {
                ret = self._taskPriority
            }
            return ret
        }
    }

    public var authorizer: CTLAuthorizationProtocol? {
        set(auth) {
            CTLSynchronizer.synchronized {
                self._authorizer = auth
            }
        }
        get {
            var ret: CTLAuthorizationProtocol? = nil
            CTLSynchronizer.synchronized {
                ret = self._authorizer
            }
            return ret
        }
    }
    
    public var responseValidator: CTLResponseValidationProtocol? {
        set(val) {
            CTLSynchronizer.synchronized {
                self._responseValidator = val
            }
        }
        get {
            var ret: CTLResponseValidationProtocol? = nil
            CTLSynchronizer.synchronized {
                ret = self._responseValidator
            }
            return ret
        }
    }

    public var retryEnabled: Bool {
        set(enable) {
            CTLSynchronizer.synchronized {
                self._retryEnabled = enable
            }
        }
        get {
            var ret: Bool = false
            CTLSynchronizer.synchronized {
                ret = self._retryEnabled
            }
            return ret
        }
    }

    public fileprivate(set) var retryCount: UInt {
        set(count) {
            CTLSynchronizer.synchronized {
                self._retryCount = count
            }
        }
        get {
            var ret: UInt = 0
            CTLSynchronizer.synchronized {
                ret = self._retryCount
            }
            return ret
        }
    }

    public var maxRetryCount: UInt {
        set(max) {
            CTLSynchronizer.synchronized {
                self._maxRetryCount = max
            }
        }
        get {
            var ret: UInt = 0
            CTLSynchronizer.synchronized {
                ret = self._maxRetryCount
            }
            return ret
        }
    }

    public var retryBlock: CTLSessionFetcherRetryBlock? {
        set(retryBlock) {
            CTLSynchronizer.synchronized {
                self._retryBlock = retryBlock
            }
        }
        get {
            var ret: CTLSessionFetcherRetryBlock? = nil
            CTLSynchronizer.synchronized {
                ret = self._retryBlock
            }
            return ret
        }
    }

    public var keeper: CTLSessionFetcherKeeper? {
        set(keeper) {
            CTLSynchronizer.synchronized {
                self._keeper = keeper
            }
        }
        get {
            var ret: CTLSessionFetcherKeeper? = nil
            CTLSynchronizer.synchronized {
                ret = self._keeper
            }
            return ret
        }
    }

    fileprivate(set) var underlyingRequest: Request? {
        set(req) {
            CTLSynchronizer.synchronized {
                self._underlyingRequest = req
            }
        }
        get {
            var ret: Request? = nil
            CTLSynchronizer.synchronized {
                ret = self._underlyingRequest
            }
            return ret
        }
    }

    public var session: URLSession {
        get {
            var ret: URLSession? = nil
            CTLSynchronizer.synchronized {
                ret = self.alamofireManager.session
            }
            return ret!
        }
    }

    public var sessionTask: URLSessionTask? {
        get {
            var ret: URLSessionTask? = nil
            CTLSynchronizer.synchronized {
                ret = self._underlyingRequest?.task
            }
            return ret
        }
    }

    public var sessionDelegate: CTLSessionDelegateProtocol {
        set(delegate) {
            CTLSynchronizer.synchronized {
                self._sessionDelegate = delegate
            }
        }
        get {
            var ret: CTLSessionDelegateProtocol? = nil
            CTLSynchronizer.synchronized {
                ret = self._sessionDelegate
            }
            return ret!
        }
    }

    internal static var sharedAlamofireManager: SessionManager {
        set(manager) {
            CTLSynchronizer.synchronized {
                CTLSessionFetcher._sharedAlamofireManager = manager
            }
        }

        get {
            var ret: SessionManager? = nil
            CTLSynchronizer.synchronized {
                ret = CTLSessionFetcher._sharedAlamofireManager
            }
            return ret!
        }
    }
}


/**
    Retrying
 */
public extension CTLSessionFetcher {
    
    func shouldRetryNow(status: Int, error: NSError?, response: CTLSessionFetcherRetryResponse) {
    
        var willRetry = false
        /// Don't expect this function to be called within synchronization block
        CTLSynchronizer.requireNoSynchronized()
        
        if (self.retryEnabled) {
            if self.retryCount <= self.maxRetryCount {
                willRetry = (self.isRetryError(error) || self.isRetryStatus(status))
            }
        
            if let retryBlock = self.retryBlock {
                retryBlock(willRetry, error, response)
                return
            }
        }
        
        response(willRetry)
    }

    fileprivate func isRetryError(_ error: NSError?) -> Bool {
        /// TODO: identify recoverable errors
        return false
    }

    fileprivate func isRetryStatus(_ status: Int) -> Bool {
        let retries: [Int] = [408, 502, 503, 504]
        return retries.contains(status)
    }
}


/**
    Internal/Private functions
 */
extension CTLSessionFetcher {

    fileprivate func registerAlamofireCallbacks() {

        if let delegate = self.alamofireManager.delegate as? AWCTLSessionDelegate {

            delegate.taskDidReceiveChallengeWithEscapingCompletion = { [weak self] (session, task, challenge, completion) in

                guard let weakSelf = self  else { return }

                if let taskChallengeCallback = CTLSessionFetcher.sharedSessionDelegate.sessionDidReceiveChallengeWithCompletion {
                    log(info: "Handled Challenge with Common Session Delegate Challenge Handler")
                    taskChallengeCallback(weakSelf, challenge, completion)
                } else if let taskChallengeCallback = weakSelf.sessionDelegate.sessionDidReceiveChallengeWithCompletion {
                    log(info: "Handled Challenge with Fetcher Specific Session Delegate Challenge Handler")
                    taskChallengeCallback(weakSelf, challenge, completion)
                } else {
                    log(info: "Performing default handlging on the Challenge")
                    completion(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
                }
            }
        } else {
            log(error: "Provided Delegate is not AWCTLSessionDelegate. can not handle Server Trust with non escaping completion block")
        }

        self.alamofireManager.delegate.taskWillPerformHTTPRedirectionWithCompletion =
            {[weak self] (session: URLSession, task: URLSessionTask, response: HTTPURLResponse, request: URLRequest, completionHandler: (URLRequest?) -> Void) in
                guard let weakSelf = self  else { return }

                if let taskRedirectionCallback = CTLSessionFetcher.sharedSessionDelegate.sessionWillPerformHTTPRedirectionWithCompletion {
                    log(info: "Handling Redirection with Common Session Delegate Redirect Handler")
                    taskRedirectionCallback(weakSelf, response, request, completionHandler)
                } else if let taskRedirectionCallback = weakSelf.sessionDelegate.sessionWillPerformHTTPRedirectionWithCompletion {
                    log(info: "Handling Redirection with Fetcher Specific Session Delegate Redirect Handler")
                    taskRedirectionCallback(weakSelf, response, request, completionHandler)
                } else {
                    log(info: "Not Handling Redirection")
                    completionHandler(request)
                }
        }
    }
}

/**
    String representation
 */
extension CTLSessionFetcher {
    open override var description: String {
        return "TBD"
    }
}


extension CTLSessionFetcher {
    open override var debugDescription: String {
        return "TBD"
    }
}
