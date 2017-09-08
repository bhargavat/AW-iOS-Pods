//
//  TokenAuthenticationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWError
import AWLocalization
import AWPresentation
import AWNetwork

extension AWError.SDK {
    public enum TokenAuthentication: AWErrorType {
        case missingRequiredInformation
        case missingAuthenticationToken
        case cannotVerifyToken
    }

    public enum ManagedSettingsTokenAuthentication: AWErrorType {
        case authenticationTokenNotAvailable
        case authenticationTokenAlreadyConsumed
    }

}

internal class TokenAuthenticationOperation: IdentitySetupOperation {
    internal var authenticationToken: String?  = nil

    internal override func performAuthentication() {
        self.performTokenAuthentication()
    }

    internal func performTokenAuthentication() {
        guard let token = self.authenticationToken else {
            self.identity = nil
            self.identitySetupError = AWError.SDK.TokenAuthentication.missingAuthenticationToken
            self.markOperationFailed()
            return
        }

        self.authenticate(token: token) { (hmacToken, error) in

            guard let hmacToken = hmacToken, error == nil else {
                log(error: "Can not verify provided token. Error: \(String(describing: error))")
                //if error is network error? prompt with failure
                self.identitySetupError = AWError.SDK.TokenAuthentication.cannotVerifyToken
                self.markOperationFailed()
                return
            }

            let enrollmentAccount = AWEnrollmentAccount(activationCode: self.dataStore.enrollmentInformation?.organizationGroup,
                                                        authorizationToken: token)

            log(debug: "HMAC Received: \(hmacToken)")
            self.createIdentity(hmacToken: hmacToken, account: enrollmentAccount)
        }
    }

    override func identitySetupComplete() {
        self.markOperationComplete()
    }

    /**
     * Errors returned from completion Handler are...
     * AWError.SDK.General.configurationValuesUnavailable - If the common or console service config is unavailable
     * AWError.SDK.General.internalServerError - Problem with the retrieval of the hmac
     * A NSError - returned from the network layer
     */
    typealias TokenAuthenticationCompletionHandler = (String?, Error?)->Void
    func authenticate(token: String, completion: @escaping TokenAuthenticationCompletionHandler) {

        guard
            let authConfig = self.authenticatorConfig,
            let remoteAuthentication = try? UserRemoteAuthentication(configValues: authConfig)
        else {
            log(error: "Missing Required Configuration to setup authetnicator")
            completion(nil, AWError.SDK.TokenAuthentication.missingRequiredInformation)
            return
        }

        do {

            _ = try remoteAuthentication.authenticateUserToRetrieveHMAC(AuthorizationToken: token) { [weak self] (authToken, error) in
                if let error = error,
                    let httpResponse = error.userInfo[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse,
                    httpResponse.statusCode == 200 {
                    self?.dataStore.lastVerifiedOneTimeToken = token
                }

                guard let hmacToken = authToken?.token.hmacToken, error == nil else {
                    log(error: "Can not login user with One Time token. Failed to get HMAC Token from oneTime Token. Error: \(String(describing: error))")
                    completion(nil, error)
                    return
                }

                log(info: "Token Login is Successful")
                completion(hmacToken, nil)
            }
        } catch {
            completion(nil, AWError.SDK.General.missingParameters)
        }
    }
}

internal class ManagedTokenAuthenticationOperation: TokenAuthenticationOperation {
    
    override func performAuthentication() {
        guard let onetimeTokenFromManagedSettings = SDKManagedSettings.currentSetings.oneTimetoken else {
            self.identitySetupError = AWError.SDK.ManagedSettingsTokenAuthentication.authenticationTokenNotAvailable
            self.markOperationComplete()
            return
        }

        guard onetimeTokenFromManagedSettings != self.dataStore.lastVerifiedOneTimeToken else {
            log(info: "One Time Token is available from Managed Settings that was not used before")
            self.identitySetupError = AWError.SDK.ManagedSettingsTokenAuthentication.authenticationTokenAlreadyConsumed
            self.markOperationComplete()
            return
        }

        self.authenticationToken = onetimeTokenFromManagedSettings
        self.performTokenAuthentication()
        return
    }
}
