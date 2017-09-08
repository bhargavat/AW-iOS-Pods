//
//  UserRemoteAuthentication.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWNetwork
import AWError
import UIKit
import Alamofire

public protocol UserAuthConfig {
    var airWatchServerURL: String { get }
    var organizationGroup: String { get }
    var deviceId: String { get }
    var deviceType: String { get }
    var bundleId: String { get }
    var requestingApp: String { get }
    var authenticationGroup: String { get }
}

extension AWServices {
    public enum AuthorizationToken {
        case hmac(String)
        case authenticationToken(String)
        case authenticationCertificate(String)

        public var hmacToken: String? {
            switch self {
            case let .hmac(token):
                return token
            default:
                return nil
            }
        }

        public var authToken: String? {
            switch self {
            case let .authenticationToken(authToken):
                return authToken
            default:
                return nil
            }
        }

        public var authCertToken: String? {
            switch self {
            case let .authenticationCertificate(certToken):
                return certToken
            default:
                return nil
            }
        }
    }
}

internal enum AuthorizationType: Int {
    case authorizationToken = 1
    case hmacToken = 2
    case hmacAndAuthToken = 3
    case certificateToken = 4
    case authTokenAndCertificate = 5
    case hmacAndCertificate = 6
    case authHMACAndCertificate = 7

    private var authTokenResponseKey: String? {
        switch self {
        case  .hmacToken:
            return AuthenticationConstants.kAWAuthResponseAWHMACKey

        case .authorizationToken:
            return AuthenticationConstants.kAWAuthResponseAuthorizationTokenKey

        case .certificateToken:
            return AuthenticationConstants.kAWAuthResponseAuthenticationCertificateKey

        default:
            return nil
        }
    }

    internal func processedToken(from response: [String: AnyObject]) -> AWServices.AuthorizationToken? {
        guard let tokenKey = self.authTokenResponseKey, let tokenValue = response[tokenKey] as? String else {
            return nil
        }

        switch (self) {
        case  .hmacToken:
            return .hmac(tokenValue)

        case .authorizationToken:
            return .authenticationToken(tokenValue)

        case .certificateToken:
            return .authenticationCertificate(tokenValue)

        default:
            return nil
        }
    }
}

public class UserRemoteAuthentication {

    private class SessionTaskDelegate: NSObject, URLSessionTaskDelegate {

        public var redirectedURL: URL? = nil
        public var redirectCount: Int = 0

        public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Swift.Void) {

            guard self.redirectCount < 10 else {
                completionHandler(nil)
                return
            }

            self.redirectedURL = request.url
            self.redirectCount += 1
            completionHandler(request)
            return
        }
        
    }

    public typealias AuthTokenCompletionHandler = (_ AuthToken: UserRemoteAuthResponse?, _ error: NSError?) -> Void
    public typealias SAMLUrlCompletionHandler = (_ SAMLUrl: URL?, _ error: NSError?) -> Void
    public typealias ConsoleVersionCompletionHandler = (_ Version: VersionResponse?, _ url: String?, _ error: Error?) -> Void

    internal static var session = URLSession(configuration: .default, delegate: UserRemoteAuthentication.SessionTaskDelegate(), delegateQueue: nil)

    internal let config: UserAuthConfig
    internal var authenticationEndpointURL: URL //TODO:: WILLIAM Look at this
    internal static var DefaultFetcherType = CTLSessionFetcher.self

    public required init(configValues: UserAuthConfig) throws {

        guard configValues.deviceId.characters.count > 0 else {
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        guard configValues.deviceType.characters.count > 0 else {
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        guard configValues.authenticationGroup.characters.count > 0 else {
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        self.config = configValues
        self.authenticationEndpointURL = try UserRemoteAuthentication.constructAuthenticationEndPointURL(configValues.airWatchServerURL)
    }

    fileprivate static func constructAuthenticationEndPointURL(_ hostname: String) throws -> URL {
        let unacceptableCharset = NSMutableCharacterSet()
        unacceptableCharset.formUnion(with: CharacterSet.whitespacesAndNewlines)
        unacceptableCharset.formUnion(with: CharacterSet(charactersIn: "./"))

        let hostURL = hostname.trimmingCharacters(in: unacceptableCharset as CharacterSet)

        guard let completeURL = URL(string: hostURL + AuthenticationConstants.kAWAuthEndpoint) , !hostURL.isEmpty else {

            log(debug: "Received invalid AirWatch Server URL String")
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        return completeURL

    }

    /**
     Athenticates a user against the server for HMAC Key

     - Parameter userName:   The string of the user's name.
     - Parameter password: The string of the same user's password.
     - Parameter completionHandler: closure taking in a String? and NSError?, for handling returned values

     - Throws: `AWError.SDK.Service.Authorization.InvalidInputs` if any required parameters have invalid inputs.

     - Returns: CTLTask<UserRemoteAuthResponse>?
     */
    public func authenticateUserToRetrieveHMAC(UserName userName: String, Password password: String, CompletionHandler completionHandler: @escaping AuthTokenCompletionHandler) throws -> Void {
        /// Protect against invalid inputs
        guard !userName.isEmpty && !password.isEmpty
            else { throw AWError.SDK.Service.Authorization.invalidInputs  }

        let payload = try createRequestBodyWith(UserName: userName, Password: password, AndActivationCode: config.organizationGroup, OrAuthorizationToken: nil)
        self.performAuthentication(payload: payload, completionHandler: completionHandler)
    }

    /**
     Athenticates a user against the server for HMAC Key

     - Parameter authorizationToken: The string value of the auth token.
     - Parameter completionHandler: closure taking in a String? and NSError?, for handling returned values

     - Throws: `AWError.SDK.Service.Authorization.InvalidInputs` if any required parameters have invalid inputs.

     - Returns: CTLTask<UserRemoteAuthResponse>?
     */
    public func authenticateUserToRetrieveHMAC(AuthorizationToken authorizationToken: String, CompletionHandler completionHandler: @escaping AuthTokenCompletionHandler) throws -> Void {
        /// Protect against invalid inputs
        guard authorizationToken.characters.count > 0 else {
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        let payload = try createRequestBodyWith(UserName: nil, Password: nil, AndActivationCode: nil, OrAuthorizationToken: authorizationToken)
        self.performAuthentication(payload: payload, completionHandler: completionHandler)
    }

    /**
     Athenticates a user against the server for Auth Token

     - Parameter userName: The string of the user's name.
     - Parameter password: The string of the same user's password.
     - Parameter completionHandler: closure taking in a String? and NSError?, for handling returned values

     - Throws: `AWError.SDK.Service.Authorization.InvalidInputs` if any required parameters have invalid inputs.

     - Returns: CTLTask<UserRemoteAuthResponse>? object
     */
    public func authenticateUserToRetrieveAuthToken(UserName userName: String, Password password: String, CompletionHandler completionHandler: @escaping AuthTokenCompletionHandler) throws -> Void {
        /// Protect against invalid inputs
        guard userName.characters.count > 0 && password.characters.count > 0 else {
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        let payload = try createRequestBodyWith(UserName: userName, Password: password, AndActivationCode: config.organizationGroup, OrAuthorizationToken: nil, authType: AuthorizationType.authorizationToken)
        self.performAuthentication(payload: payload, completionHandler: completionHandler)
    }

    /**
     Queries AW Server for SAML redirect URL for User Authentication if it has been configured on the Server

     - Parameter URLScheme:   The string of the URL scheme that is to be used for giving back token data on successful authentication.
     - Parameter completionHandler: closure taking in a NSURL? and NSError?, for handling returned values.  NSURL should be loaded in a webview looking for the URLScheme as a redirect on successful authentication.

     - Throws: `AWError.SDK.Service.Authorization.InvalidInputs` if any required parameters have invalid inputs.

     - Returns: CTLTask<SAMLResponseObject>?
     */
    public func retrieveSAMLRedirectUrl(_ redirectURLScheme: String, completionHandler: @escaping SAMLUrlCompletionHandler) throws -> Void {
        guard redirectURLScheme.isEmpty == false else {
            throw AWError.SDK.Service.Authorization.invalidInputs
        }

        var urlRequest = URLRequest(url: self.authenticationEndpointURL)
        urlRequest.httpMethod = HTTPConstants.kHTTPMethodGet
        urlRequest.setValue(config.organizationGroup, forHTTPHeaderField: AuthenticationConstants.kAWAuthActivationCodeKey)
        urlRequest.setValue(config.deviceId, forHTTPHeaderField: AuthenticationConstants.kAWAuthUdidKey)
        urlRequest.setValue(config.deviceType, forHTTPHeaderField: AuthenticationConstants.kAWAuthDeviceTypeKey)
        urlRequest.setValue(config.bundleId, forHTTPHeaderField: AuthenticationConstants.kAWAuthBundleIdKey)
        urlRequest.setValue(config.requestingApp, forHTTPHeaderField: AuthenticationConstants.kAWAuthRequestingAppKey)
        urlRequest.setValue("\(AuthorizationType.authorizationToken.rawValue)", forHTTPHeaderField: AuthenticationConstants.kAWAuthAuthTypeKey)
        urlRequest.setValue(config.authenticationGroup, forHTTPHeaderField: AuthenticationConstants.kAWAuthAuthGroupKey)
        urlRequest.setValue(redirectURLScheme, forHTTPHeaderField: AuthenticationConstants.kAWAuthRedirectUrlKey)
        urlRequest.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData

        class SAMLResponseProcessor {
            let completionHandler: SAMLUrlCompletionHandler
            init(handler: @escaping SAMLUrlCompletionHandler) {
                self.completionHandler = handler
            }

            func processSAMLResponse(rsp: SAMLResponse?, error: NSError?) {
                guard let rsp = rsp,
                    let properties = rsp.properties,
                    let httpResponse = properties[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse else {
                        let failureError = error ?? AWError.SDK.Service.Authorization.invalidServerResponse.error
                        self.completionHandler(nil, failureError)
                        return
                }

                if httpResponse.statusCode == 401 {
                    if let samlResponseData = rsp.data,
                        let SAMLUrl = self.getSAMLUrlFromSAMLResponseData(samlResponseData) {
                        self.completionHandler(SAMLUrl, nil)
                    } else {
                        self.completionHandler(nil, AWError.SDK.Service.Authorization.invalidServerResponse.error)
                    }
                } else if httpResponse.statusCode == 200 {
                    self.completionHandler(nil, nil)
                } else { /// Error
                    self.completionHandler(nil, AWError.SDK.Service.Authorization.unexpectedServerResponseWithURLStatusCode(statusCode: httpResponse.statusCode).error)
                }
            }

            private func getSAMLUrlFromSAMLResponseData(_ samlResponseData: Data) -> URL? {
                guard let jsonDictionaryTemp = try? JSONSerialization.jsonObject(with: samlResponseData, options: []),
                    let jsonDictionary = jsonDictionaryTemp as? [String: AnyObject],
                    let urlString = jsonDictionary[AuthenticationConstants.kAWAuthRedirectUrlKey] as? String,
                    let SAMLUrl = URL(string: urlString) else {
                        return nil
                }
                
                return SAMLUrl
            }

        }

        let fetcher = UserRemoteAuthentication.DefaultFetcherType.fetcherWithRequest(urlRequest)
        let processor = SAMLResponseProcessor(handler: completionHandler)
        fetcher.responseValidator = AirWatchHeaderValidator()
        _ = fetcher.beginFetch(on: nil, mayAuthorize: false) { (rsp: SAMLResponse?, error: NSError?) in
            processor.processSAMLResponse(rsp: rsp, error: error)
        }
    }


    // MARK: - House Keeping Method
    /**
     Class method for retrieving the Console version from a given URL

     - Parameter serverURL:   The URL of the AirWatch Server you would like the version of.
     - Parameter completionHandler: closure taking in a String? and NSError?, for handling returned values.

     - Throws: `AWError.SDK.Service.Authorization.InvalidInputs` if any required parameters have invalid inputs.

     - Returns: Void
     */
    public class func retrieveConsoleVersion(_ serverURL: String,
                                             allowRedirection: Bool = true,
                                             completionHandler: @escaping ConsoleVersionCompletionHandler) throws -> Void {

        var urlToValidate = URL(string: serverURL)
        if allowRedirection == false {
            urlToValidate = try UserRemoteAuthentication.constructAuthenticationEndPointURL(serverURL)
        }

        guard let url = urlToValidate else {
            completionHandler(nil, nil, nil)
            return
        }

        // We need to hit the server first to see if it will redirect us. 
        // If we are redirected, get the url from the response and use its URL for the urlRequest object. 
        // If there wasn't a redirect, then the URLResponse will be the same as the url

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPConstants.kHTTPMethodHead
        urlRequest.setValue("Airwatch", forHTTPHeaderField: "User-Agent")

        // If this is not sent to the server, it will not return to us the redirect URL if one is available. 
        // To see an example attempt to enroll into cnmain.airwatchdev.com and you will receive a response 
        // with dsmain.airwatchdev.com/{some path}

        let task = session.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if error != nil {
                completionHandler(nil, nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                let resolvedHost = UserRemoteAuthentication.getResolvedHost(httpResponse: httpResponse) else {
                    completionHandler(nil, nil, AWError.SDK.Server.unexpectedServerResponse.error)
                    return
            }

            if let version = UserRemoteAuthentication.getConsoleVersion(httpResponse: httpResponse) {
                completionHandler(version, resolvedHost, nil)
            } else if allowRedirection {
                try? UserRemoteAuthentication.retrieveConsoleVersion(resolvedHost, allowRedirection: false, completionHandler: completionHandler)
            } else {
                completionHandler(nil, nil, AWError.SDK.Server.unexpectedServerResponse.error)
            }
        }
        
        task.resume()
    }

    private static func getResolvedHost(httpResponse: HTTPURLResponse) -> String? {

        guard let resolvedURL = httpResponse.url else {
            return nil
        }

        var urlComponents = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false)
        urlComponents?.path = ""
        let resolvedHost = urlComponents?.url?.absoluteString
        return resolvedHost
    }

    private static func getConsoleVersion(httpResponse: HTTPURLResponse) -> VersionResponse? {

        if let headers = httpResponse.allHeaderFields as? [String: AnyObject],
            let versionHeader = headers[AuthenticationConstants.kAWAuthResponseHeaderAWVersionKey] as? String,
            versionHeader.characters.count > 0 {
            return VersionResponse(givenVersion: versionHeader)
        }

        return nil
    }

    private func performAuthentication(payload: Data, completionHandler: @escaping AuthTokenCompletionHandler) {

        var urlRequest = URLRequest(url: self.authenticationEndpointURL)
        urlRequest.httpMethod = HTTPConstants.kHTTPMethodPost
        urlRequest.httpBody = payload
        urlRequest.setValue(HTTPConstants.kHTTPHeaderAppJson, forHTTPHeaderField: HTTPConstants.kHTTPHeaderContentType)
        urlRequest.setValue(HTTPConstants.kHTTPHeaderAppJson, forHTTPHeaderField: HTTPConstants.kHTTPHeaderAccept)

        let fetcher = UserRemoteAuthentication.DefaultFetcherType.fetcherWithRequest(urlRequest)
        fetcher.responseValidator = AirWatchHeaderValidator()

        class AuthenticationResponseProcessor {
            let completionHandler: AuthTokenCompletionHandler
            init(completionHandler: @escaping AuthTokenCompletionHandler) {
                self.completionHandler = completionHandler
            }

            func processResponse(response: UserRemoteAuthResponse?, error: NSError?) {
                if let result = response {
                    self.completionHandler(result, nil)
                    return
                }

                guard let error = error else {
                    self.completionHandler(nil, AWError.SDK.Service.Authorization.unexpectedGenericError.error)
                    return
                }

                guard let networkHttpResponse = error.userInfo[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse else {
                    self.completionHandler(nil, error)
                    return
                }

                if (networkHttpResponse.statusCode != 200) {
                    log(error: "Received status code \(networkHttpResponse.statusCode) from server.")
                    self.completionHandler(nil, AWError.SDK.Service.Authorization.unexpectedServerResponseWithURLStatusCode(statusCode: networkHttpResponse.statusCode).error)
                } else {
                    self.completionHandler(nil, error)
                }
            }
        }

        let authenticationResponseProcessor = AuthenticationResponseProcessor(completionHandler: completionHandler)
        _ = fetcher.beginFetch(on: nil, mayAuthorize: false) { (response: UserRemoteAuthResponse?, error: NSError?) in
            authenticationResponseProcessor.processResponse(response: response, error: error)
        }

    }

    /*
     This method has 2 optional arguments that have default values...ActivationCode and AuthType
     The default value for ActivationCode is an empty string, as the server can lookup the OG based on device ID
     The default value for AuthType is HMACToken as this is the default response we want for an Auth Request
     */
    fileprivate func createRequestBodyWith(UserName userName: String?, Password password: String?, AndActivationCode activationCode: String? = "", OrAuthorizationToken authToken: String?, authType: AuthorizationType? = AuthorizationType.hmacToken) throws -> Data {

        let requestBodyDictionary = NSMutableDictionary()

        /// Only need Authorization Token or (Username, Password, and activationCode)
        if let userName = userName, let password = password , !userName.isEmpty && !password.isEmpty {
            requestBodyDictionary.setObject(userName, forKey: AuthenticationConstants.kAWAuthUsernameKey as NSCopying)
            requestBodyDictionary.setObject(password, forKey: AuthenticationConstants.kAWAuthPasswordKey as NSCopying)

        }
        if let authToken = authToken , !authToken.isEmpty {
            requestBodyDictionary.setObject(authToken, forKey: AuthenticationConstants.kAWAuthAuthTokenKey as NSCopying)
        }
        if let activationCode = activationCode , !activationCode.isEmpty {
            requestBodyDictionary.setObject(activationCode, forKey: AuthenticationConstants.kAWAuthActivationCodeKey as NSCopying)
        }

        requestBodyDictionary.setObject(config.deviceId, forKey: AuthenticationConstants.kAWAuthUdidKey as NSCopying)
        requestBodyDictionary.setObject(config.deviceType, forKey: AuthenticationConstants.kAWAuthDeviceTypeKey as NSCopying)
        requestBodyDictionary.setObject(config.bundleId, forKey: AuthenticationConstants.kAWAuthBundleIdKey as NSCopying)
        requestBodyDictionary.setObject(config.requestingApp, forKey: AuthenticationConstants.kAWAuthRequestingAppKey as NSCopying)
        /// Defaulting to request HMAC only
        if let authType = authType {
            requestBodyDictionary.setObject("\(authType.rawValue)", forKey: AuthenticationConstants.kAWAuthAuthTypeKey as NSCopying)
        } else { /// This 'else' is just in case the default value is removed from the optional argument of this method.
            requestBodyDictionary.setObject("\(AuthorizationType.hmacToken.rawValue)", forKey: AuthenticationConstants.kAWAuthAuthTypeKey as NSCopying)
        }

        requestBodyDictionary.setObject(config.authenticationGroup, forKey: AuthenticationConstants.kAWAuthAuthGroupKey as NSCopying)

        return try JSONSerialization.data(withJSONObject: requestBodyDictionary, options: JSONSerialization.WritingOptions.prettyPrinted)
    }

}/// End UserRemoteAuthentication Class


// MARK: - Response Classes
final public class UserRemoteAuthResponse: CTLDataObjectProtocol {

    public let token: AWServices.AuthorizationToken
    public let userId: String
    public let username: String
    public let requireEulaAccept: Bool

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> UserRemoteAuthResponse {

        guard let data = data, data.count > 0 else {
            throw AWError.SDK.Service.Authorization.missingExpectedServerResponseData
        }

        let dataString = NSString(data: data, encoding: String.Encoding.ascii.rawValue)

        log(debug: "Received data from server to convert to string: \(dataString ?? "Data not convertable to String")")

        /// Parse out the Auth Type from the original Request
        guard let additionalProperties = additionalProperties else {
            throw AWError.SDK.Service.Authorization.missingExpectedServerResponseData
        }

        guard let originalRequest = additionalProperties[CTLConstants.kCTLDataObjectURLRequest] as? NSURLRequest else {
            throw AWError.SDK.Service.Authorization.missingExpectedServerResponseData
        }

        let requestBodyData = originalRequest.httpBody

        let requestBodyJson = try? JSONSerialization.jsonObject(with: requestBodyData!, options: JSONSerialization.ReadingOptions.allowFragments)

        guard let requestBodyDict = requestBodyJson as? [String: AnyObject] else {
            throw AWError.SDK.Service.Authorization.unexpectedGenericError
        }

        guard
            let authTypeRawString = requestBodyDict[AuthenticationConstants.kAWAuthAuthTypeKey] as? String,
            let authTypeRaw = Int(authTypeRawString),
            let authType = AuthorizationType(rawValue: authTypeRaw)
            else {
                throw AWError.SDK.Service.Authorization.unexpectedGenericError
        }

        let jsonResponse: Any

        jsonResponse = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)

        guard let jsonDictionary = jsonResponse as? [String: AnyObject] else {
            throw AWError.SDK.Service.Authorization.invalidServerResponse
        }

        /// Use the AuthType and response body to parse out pertinent information and return it
        return try UserRemoteAuthResponse(jsonDictionary: jsonDictionary, authType: authType)
    }

    init(jsonDictionary: [String: AnyObject], authType: AuthorizationType) throws {

        let AuthResult = try UserRemoteAuthResponse.processResponse(JsonDictionary: jsonDictionary, andAuthenticationType: authType)

        guard let givenUsername = jsonDictionary[AuthenticationConstants.kAWAuthResponseUsernameKey] as? String else {
            throw AWError.SDK.Service.Authorization.unexpectedGenericError
        }

        guard let givenUserId = jsonDictionary[AuthenticationConstants.kAWAuthResponseUserIdKey] as? String else {
            throw AWError.SDK.Service.Authorization.unexpectedGenericError
        }

        guard let givenEulaRequirement = jsonDictionary[AuthenticationConstants.kAWAuthResponseEulaKey] as? NSString else {
            throw AWError.SDK.Service.Authorization.unexpectedGenericError
        }

        if givenEulaRequirement.lowercased == "false" || givenEulaRequirement.lowercased == "no" || givenEulaRequirement.intValue == 0 {
            self.requireEulaAccept = false
        } else {
            self.requireEulaAccept = true
        }

        self.token = AuthResult
        self.username = givenUsername
        self.userId = givenUserId
    }

    fileprivate class func processResponse(JsonDictionary jsonDictionary: [String: AnyObject], andAuthenticationType authType: AuthorizationType) throws -> AWServices.AuthorizationToken {

        let authenticationErrorsMap: [String: AWError.SDK.Service.Authorization] = [
            "AUTH-1001": .invalidCredentials,
            "AUTH-1002": .accountLockedOut,
            "AUTH-1003": .inactiveAccount,
            "AUTH-1004": .notMDMEnrolled,
            "AUTH-1005": .invalidToken,
            "AUTH-1006": .deviceNotFound,
            "AUTH-1007": .serverConfigurationIssue,
            "AUTH--1": .unknownServerIssue ]

        guard let statusCode = jsonDictionary[AuthenticationConstants.kAWAuthResponseStatusCodeKey] as? String else {
            throw AWError.SDK.Service.Authorization.invalidServerResponse
        }

        if let error = authenticationErrorsMap[statusCode] {
            log(error: "Auth Error: \(error)")
            throw error
        }

        if statusCode == "AUTH-0",
            let processesToken = authType.processedToken(from: jsonDictionary) {
                log(debug: "Server says, \"Everything is good\". We have the Authentication token")
                return processesToken
        }

        log(error: "Unable to understand the Auth Response...")
        throw AWError.SDK.Service.Authorization.unexpectedGenericError
    }
}

final public class SAMLResponse: CTLDataObjectProtocol {
    var data: Data? = nil
    var properties: [String: AnyObject]? = nil
    var error: AWError.SDK.Service.Authorization? = nil

    public init() {

    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> SAMLResponse {
        let responseObject: SAMLResponse

        let dataString = NSString(data: data!, encoding: String.Encoding.ascii.rawValue)

        log(debug: "Received SAML data from server to convert to string: \(dataString ?? "Data not convertable to String")")

        responseObject = SAMLResponse()
        responseObject.data = data
        responseObject.properties = additionalProperties
        return responseObject
    }
}

final public class VersionResponse: CTLDataObjectProtocol {
    public let version: String
    init(givenVersion: String) {
        self.version = givenVersion
    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> VersionResponse {
        guard let properties = additionalProperties else {
            throw AWError.SDK.Service.Authorization.invalidServerResponse
        }

        guard let networkResponse = properties[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse else {
            throw AWError.SDK.Service.Authorization.invalidServerResponse
        }
        
        if let headers = networkResponse.allHeaderFields as? [String: AnyObject] {
            if let versionHeader = headers[AuthenticationConstants.kAWAuthResponseHeaderAWVersionKey] as? String , versionHeader.characters.count > 0 {
                return VersionResponse(givenVersion: versionHeader)
            }
        }
        
        throw AWError.SDK.Service.Authorization.invalidServerResponse
    }
}

extension AWServices.AuthorizationToken: Equatable {
    public static func ==(left: AWServices.AuthorizationToken, right: AWServices.AuthorizationToken) -> Bool {
        switch (left, right) {
        case (let .hmac(token1), let .hmac(token2)):
            return token1 == token2
            
        case (let .authenticationToken(token1), let .authenticationToken(token2)):
            return token1 == token2
            
        case (let .authenticationCertificate(token1), let .authenticationCertificate(token2)):
            return token1 == token2
            
        default:
            return false
        }
    }
}

