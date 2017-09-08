//
//  SAMLAuthenticationOperation.swift
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

extension AWError.SDK {
    public enum SAMLAuthentication: AWErrorType {
        case incompleteSetup
        case notAvailable
        case invalidURLFormat
        case incomplete
    }

}

class SAMLAuthenticationOperation: TokenAuthenticationOperation, SAMLTokenDelegate {

    private var callbackScheme: String {
        guard
            let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: AnyObject]],
            let first = urlTypes.first,
            let schemes = first["CFBundleURLSchemes"] as? [String],
            let appScheme = schemes.first
            else {
                return "sdksampleApp"
        }
        return appScheme
    }

    private var SAMLCallbackURLString: String {
        return "\(self.callbackScheme)://SAMLAuthentication?"
    }

    internal override func performAuthentication() {
        self.performSAMLAuthentication()
    }

    internal func performSAMLAuthentication() {
        guard authenticationServices != nil else {
            log(error: "Authentication Services is nil")
            self.identity = nil;
            self.identitySetupError = AWError.SDK.SAMLAuthentication.incompleteSetup
            return
        }

        self.getSAMLAuthenticationURL { [weak self] (success, SAMLUrl) in
            guard let currentOperation = self else {
                log(info: "Current Operations is cleared while waiting on user input for SAML")
                return
            }

            guard success else {
                log(info: "SAML Authentication is not available on this server. Should continue using Username and Password")
                currentOperation.identity = nil;
                currentOperation.identitySetupError = AWError.SDK.SAMLAuthentication.notAvailable
                currentOperation.identitySetupComplete()
                return
            }

            log(info: "SAML Authentication is configured on this server. Will prompt to authenticate using SAML")

            guard let url = SAMLUrl else {
                log(info: "Invalid SAML Components, Can not parse, falling back to username and password")
                currentOperation.identity = nil;
                currentOperation.identitySetupError = AWError.SDK.SAMLAuthentication.invalidURLFormat
                currentOperation.identitySetupComplete()
                return
            }

            struct Configuration: SAMLConfigurtion {
                var url: URL
                var callbackScheme: String
            }
            
            let configuration = Configuration(url: url, callbackScheme: currentOperation.callbackScheme)
            currentOperation.presenter.performSAMLAuthentication(configurtion: configuration,
                                                                 options: SAMLAuthenticationOptions.allowCancel,
                                                                 delegate: currentOperation)
        }
    }

    private func getSAMLAuthenticationURL(completion: @escaping ((Bool, URL?) -> Void) ) {
        do {
            _ = try self.authenticationServices?.retrieveSAMLRedirectUrl(self.SAMLCallbackURLString) { (SAMLUrl, error) in
                guard let samlServiceURL = SAMLUrl else {
                    log(verbose: "SAML not available")
                    completion(false, nil)
                    return
                }

                log(verbose: "Retrieved SAML URL :\(samlServiceURL)")
                completion(true, samlServiceURL)
            }
        } catch let error {
            log(error: "Error Trying to retrieve SAML URL: \(error)")
            completion(false, nil)
        }
    }

    func didReceive(token: String?, error: NSError?) {
        guard let token = token, error == nil else {
            log(error: "No token was received and error is: \(String(describing: error))")
            self.identity = nil
            self.identitySetupError = AWError.SDK.SAMLAuthentication.incomplete
            self.markOperationFailed()
            return
        }
        log(info: "Recieved Authentication token after SAML Authentication. Will get the HMAC using the token")
        self.authenticationToken = token
        self.performTokenAuthentication()
    }

    override func identitySetupComplete() {
        self.markOperationComplete()
    }
}
