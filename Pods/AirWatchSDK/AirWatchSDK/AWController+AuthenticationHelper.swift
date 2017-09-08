//
//  AWController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

import AWError

extension AWController {
    
    @objc(canHandleProtectionSpace:withError:)
    public func canHandle(protectionSpace: URLProtectionSpace?) throws -> Void {
        log(info: "Checking if can handle protection space given.")
        guard
            let protectionSpace = protectionSpace,
            self.authHandler.canHandle(protectionSpace: protectionSpace) else {
            throw AWError.SDK.AuthenticationChallengeHandler.canNotHandleProtectionSpace
        }
    }
    
    @objc(handleChallengeForURLSession:completionHandler:)
    public func handleChallengeForURLSession(challenge: URLAuthenticationChallenge?, completionHandler: ((URLSession.AuthChallengeDisposition, URLCredential?) -> Void)?) -> Bool {
        log(info: "Starting to handle challenge for URL Session.")

        guard let challenge = challenge else {
            return false
        }

        let method = challenge.protectionSpace.authenticationMethod
        if method == NSURLAuthenticationMethodHTTPBasic || method == NSURLAuthenticationMethodNTLM || method == NSURLAuthenticationMethodClientCertificate {
            return self.authHandler.handle(challenge: challenge, completion: completionHandler)
        }

        return false
    }
    
    fileprivate enum ErrorCode: Int {
        case containerLocked = 0
        case failedToFetchSDKProfile = 1
        case failedToEnforceIdentityPolicy = 2
    }
    
    @objc(clearAndRefetchClientCertificateCredentialsWithCompletionHandler:)
    public func clearAndRefetchClientCertificateCredentials(completionHandler: @escaping (Bool, NSError?) -> Void) -> Void {

        CertificateStore(with: self.context).clearCert()
        
        guard self.canAccessProtectedData() else {
            log(error: "Data Store is locked, Can not perform resetting")
            completionHandler(false, AWError.SDK.ResetClientCertificateCredentials.internal(code: ErrorCode.containerLocked.rawValue).error)
            return
        }
        
        let profileFetchOperation = ConfigurationProfileFetchOperation(sdkController: self,
                                                                       presenter: self.presenter,
                                                                       dataStore: self.context)
        log(debug: "CPFOP: \(Unmanaged<AnyObject>.passUnretained(profileFetchOperation as AnyObject).toOpaque())")
        profileFetchOperation.deviceServices = self.dataStore.deviceServices
        profileFetchOperation.completionBlock = {[weak profileFetchOperation] in

            guard let operation = profileFetchOperation,
                operation.operationCompletedSuccessfully else {
                log(error: "Failed to fetch SDK profile")
                completionHandler(false, AWError.SDK.ResetClientCertificateCredentials.internal(code: ErrorCode.failedToFetchSDKProfile.rawValue).error)
                return
            }
            
            AWController.sharedInstance.fetchClientCertificateCredentials(completionHandler: completionHandler)
        }
        
        SDKOperationQueue.workerQueue.addOperation(profileFetchOperation)
    }
    
    
    private func fetchClientCertificateCredentials(completionHandler: @escaping (Bool, NSError?) -> Void) {
        
        guard self.canAccessProtectedData() else {
            log(error: "Data Store is locked, Can not perform resetting")
            completionHandler(false, AWError.SDK.ResetClientCertificateCredentials.internal(code: ErrorCode.containerLocked.rawValue).error)
            return
        }
        
        let identityPolicyEnforcer = IdentityPolicyEnforcer(sdkController: self,
                                                            presenter: self.presenter,
                                                            dataStore: self.context)
        identityPolicyEnforcer.completionBlock = {
            guard identityPolicyEnforcer.operationCompletedSuccessfully else {
                log(error: "Failed to enforce the IdentityPolicyEnforcer")
                completionHandler(false, AWError.SDK.ResetClientCertificateCredentials.internal(code: ErrorCode.failedToEnforceIdentityPolicy.rawValue).error)
                return
            }
            completionHandler(true, nil)
        }
        
        SDKOperationQueue.workerQueue.addOperation(identityPolicyEnforcer)
    }
}

internal extension AWError.SDK {
    internal enum ResetClientCertificateCredentials: AWSDKErrorType {
        case `internal`(code: Int)
        
        internal var code: Int {
            switch self {
            case .internal(code: let code):
                return code
            }
        }
    }
}
