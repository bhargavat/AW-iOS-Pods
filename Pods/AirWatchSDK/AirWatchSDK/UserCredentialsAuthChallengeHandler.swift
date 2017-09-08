//
//  UserCredentialsAuthChallengeHandler.swift
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

public class UserCredentialsAuthChallengeHandler: AbstractAuthenticationChallengeHandler {

    var context: SDKContext
    
    init(context: SDKContext ) {
        self.context = context
    }

    internal var shouldHandleChallenges: Bool {
        return self.context.SDKProfile?.authenticationPayload?.enableIntegratedAuthentication ?? false
    }

    /// used within the isAbleToHandle method within the AbstractAuthenticationChallengeHandler.
    func validate(protectionSpace: URLProtectionSpace) -> Bool {
        /// is Challenge asking for username/password ? else is Challenge asking for Certificate ? else can't Handle
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodNTLM || protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else {
            return false
        }

        /// are there any credentials for the URL in protectionSpace?
        let credentials = credential(forProtectionSpace: protectionSpace)
        return credentials != nil
    }

    /// returns a URLCredential if any exists for the host in the given protectionSpace.
    func credential(forProtectionSpace: URLProtectionSpace) -> URLCredential? {
        let serverURL = self.challengingServerURLString(protectionSpace: forProtectionSpace)

        guard let credentials = credentials(forURL: serverURL) else {
            return nil
        }

        return credentials
    }

    func credential(forProtectionSpace: URLProtectionSpace, completion: @escaping (URLCredential?) -> Void) {
        let serverURL = self.challengingServerURLString(protectionSpace: forProtectionSpace)
        let credentials = self.credentials(forURL: serverURL)
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            completion(credentials)
        }
    }

    // MARK: Client Trust Helpers
    /// Creates a credential from a previously stored username/password.
    /// Throws an error if there are any problems creating the credential.
    func credentials(forURL urlString: String) -> URLCredential? {
        
        let certStore = CertificateStore(with:self.context)
        certStore.allowedSites = self.context.SDKProfile?.authenticationPayload?.allowedSites
        
        let hostExists = certStore.credentialExistsForHost(urlString)
        
        let account = AWController.sharedInstance.account

        guard account.username.characters.count > 0, account.password.characters.count > 0, hostExists == true else {
            log(error: "Missing Credentials for host: \(urlString). Can not authenticate user.")
            return nil
        }

        return URLCredential(user: account.username, password: account.password, persistence: URLCredential.Persistence.none)
    }
    
}
