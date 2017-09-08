//
//  AuthenticationChallengeHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWNetwork
import AWHelpers
import AWCrypto
import AWError
import Foundation

//This class sets up.
// 1. SSL Trust Hanlding
// 2. Integrated Authg for Username and password.
// 3. Certificate Based Authentication.

public class URLChallengeController: AbstractAuthenticationChallengeHandler {

    var context: SDKContext
    
    init(context: SDKContext ) {
        self.context = context
        setupServerTrustHandling()
    }

    var shouldHandleChallenges: Bool {
        return self.context.SDKProfile?.authenticationPayload?.enableIntegratedAuthentication ?? false
    }

    func createHandler(protectionSpace: URLProtectionSpace) -> AbstractAuthenticationChallengeHandler? {
        guard self.shouldHandleChallenges else {
            return nil
        }

        switch protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic: fallthrough
        case NSURLAuthenticationMethodNTLM:
            return UserCredentialsAuthChallengeHandler(context: self.context)

        case NSURLAuthenticationMethodClientCertificate:
            return ClientCertificateAuthChallengeHandler(context: self.context)

        default:
            return nil
        }
    }

    func canHandle(protectionSpace: URLProtectionSpace) -> Bool {
        log(info: "Checking if can handle protection space given.")
        guard let handler = self.createHandler(protectionSpace: protectionSpace) else {
            return false
        }
        return handler.canHandle(protectionSpace: protectionSpace)
    }

    func handle(challenge: URLAuthenticationChallenge, completion: ChallengeHandlingCompletion?) -> Bool {
        log(info: "Starting to handle challenge for URL Session.")
        log(debug: "Handling Authentication Challenge.")

        guard let handler = self.createHandler(protectionSpace: challenge.protectionSpace) else {
            /// Not any of the known Auth Methods, so perform default handling.
            log(info: "Authentication Method is outside of known bounds. Performing default handling.")
            log(debug: "Letting system handle authentication methods outside of known bounds.")

            if let completion = completion {
                completion(.performDefaultHandling, nil)
            } else if let sender = challenge.sender {
                sender.performDefaultHandling?(for: challenge)
            }

            return true
        }
        return handler.handle(challenge: challenge, completion: completion)
    }

    func validate(protectionSpace: URLProtectionSpace) -> Bool {
        log(info: "Checking if can handle protection space given.")
        guard let handler = self.createHandler(protectionSpace: protectionSpace) else {
            return false
        }
        return handler.validate(protectionSpace: protectionSpace)
    }

    func credential(forProtectionSpace: URLProtectionSpace) -> URLCredential? {
        log(info: "Checking if can handle protection space given.")
        guard let handler = self.createHandler(protectionSpace: forProtectionSpace) else {
            return nil
        }
        return handler.credential(forProtectionSpace: forProtectionSpace)
    }

    func credential(forProtectionSpace: URLProtectionSpace, completion: @escaping (URLCredential?) -> Void) {
        log(info: "Checking if can handle protection space given.")
        guard let handler = self.createHandler(protectionSpace: forProtectionSpace) else {
            completion(nil)
            return
        }

        handler.credential(forProtectionSpace: forProtectionSpace, completion: completion)
    }

    func setupServerTrustHandling() {
        /// Set AlamoFire Callback for Authentication Challenge
        let serverTrustAuthenticationHandler = ServerTrustAuthenticationHandler(context: self.context)

        CTLSessionFetcher.sharedSessionDelegate.sessionDidReceiveChallengeWithCompletion = {
            (fetcher: CTLSessionFetcher, challenge: URLAuthenticationChallenge, completionHandler: @escaping ChallengeHandlingCompletion) in

            let protectionSpace = challenge.protectionSpace

            guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
                /// Used for SSL Cert Pinning
                /// Not any of the known Auth Methods, so perform default handling.
                log(info: "Authentication Method is outside of known bounds. Performing default handling.")
                log(debug: "Letting system handle authentication methods outside of known bounds.")
                completionHandler(.performDefaultHandling, nil)
                return
            }

            log(debug: "Handling Server Trust")
            guard challenge.protectionSpace.serverTrust != nil else {
                log(error: "Expected ServerTrust to validate SSL challenge, but found none. Cancelling current Server Trust Challenge")
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            guard serverTrustAuthenticationHandler.canHandle(protectionSpace: protectionSpace) else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            serverTrustAuthenticationHandler.credential(forProtectionSpace: protectionSpace) { (credentials) in
                if let credentials = credentials {
                    completionHandler(.useCredential, credentials)
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            }
        }
    }
}
