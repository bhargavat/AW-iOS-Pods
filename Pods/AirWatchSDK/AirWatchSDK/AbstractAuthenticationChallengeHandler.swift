//
//  AbstractAuthenticationChallengeHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWNetwork
import AWCrypto
import AWError
import Foundation

internal typealias ChallengeHandlingCompletion = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

internal protocol AbstractAuthenticationChallengeHandler {

    var shouldHandleChallenges: Bool { get }
    
    func challengingServerURLString(protectionSpace: URLProtectionSpace) -> String
    func canHandle(protectionSpace: URLProtectionSpace) -> Bool
    func handle(challenge: URLAuthenticationChallenge, completion: ChallengeHandlingCompletion?) -> Bool

    func validate(protectionSpace: URLProtectionSpace) -> Bool
    func credential(forProtectionSpace: URLProtectionSpace) -> URLCredential?
    func credential(forProtectionSpace: URLProtectionSpace, completion: @escaping (URLCredential?) -> Void)
}

extension AbstractAuthenticationChallengeHandler {
    
    func canHandle(protectionSpace: URLProtectionSpace) -> Bool {
        log(info: "Checking if can handle protection space given.")

        guard self.shouldHandleChallenges else {
            return false
        }
        
        /// is Challenge asking for username/password ? else is Challenge asking for Certificate ? else can't Handle
        return self.validate(protectionSpace: protectionSpace)
    }
    
    func handle(challenge: URLAuthenticationChallenge, completion: ChallengeHandlingCompletion? = nil) -> Bool {

        log(info: "Starting to handle challenge for URL Session.")
        log(debug: "Handling Authentication Challenge.")

        guard
            challenge.previousFailureCount == 0,
            let credential = self.credential(forProtectionSpace: challenge.protectionSpace)
        else {
            log(info: "Challenge had previously failed. Cancelling Challenge.")
            log(info: "Cancel Authentication Challenge.")
            if let completion = completion {
                completion(.cancelAuthenticationChallenge, nil)
            } else {
                challenge.sender?.cancel(challenge)
            }
            return false
        }

        log(info: "Establish trust using credential.")
        if let completion = completion {
            completion(.useCredential, credential)
        } else {
            challenge.sender?.use(credential, for: challenge)
        }
        return true
    }
    
    // MARK: Generic Helpers
    func challengingServerURLString(protectionSpace: URLProtectionSpace) -> String {

        guard let givenProtocol = protectionSpace.protocol else {
            return "https://\(protectionSpace.host)"
        }
        return "\(givenProtocol)://\(protectionSpace.host)"
    }
}
