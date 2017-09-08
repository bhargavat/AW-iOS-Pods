//
//  ClientCertificateAuthChallengeHandler.swift
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

public class ClientCertificateAuthChallengeHandler: AbstractAuthenticationChallengeHandler {

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
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            return false
        }

        /// are there any credentials for the URL in protectionSpace?
        let credentials = credential(forProtectionSpace: protectionSpace)
        return credentials != nil
    }

    /// returns a URLCredential if any exists for the host in the given protectionSpace.
    func credential(forProtectionSpace: URLProtectionSpace) -> URLCredential? {
        let serverURL = self.challengingServerURLString(protectionSpace: forProtectionSpace)

        guard let credentials = certCredentials(forURL: serverURL) else {
            return nil
        }

        return credentials
    }

    func credential(forProtectionSpace: URLProtectionSpace, completion: @escaping (URLCredential?) -> Void) {

        let serverURL = self.challengingServerURLString(protectionSpace: forProtectionSpace)
        let credentials = self.certCredentials(forURL: serverURL)

        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            completion(credentials)
        }

    }


    // MARK: Client Trust Helpers
    /// Creates a credential from a previously stored integrated authentication certificate from Authentication Payload.
    /// Throws an error if there are any problems creating the credential.
    func certCredentials(forURL urlString: String) -> URLCredential? {
        
        let certStore = CertificateStore(with:self.context)
        certStore.allowedSites = self.context.SDKProfile?.authenticationPayload?.allowedSites
        
        guard certStore.certExistsForHost(urlString),
            let certInfo = certStore.certDictforHost(urlString),
            let certData = certInfo[CertficateStoreKeys.CertificateData.rawValue] as? Data,
            let password = certInfo[CertficateStoreKeys.CertificatePassword.rawValue] as? String
        else {
            log(error: "No Certificates are available for host: \(urlString)")
            return nil
        }

        guard let pkcs12 = PKCS12(p12Data: certData, password: password),
        let pkcs12Entry = pkcs12.entries.first
        else {
            log(error: "Error in parsing pkcs12 data, cannot create credentials")
            return nil
        }
        return pkcs12Entry.createURLCredential(persistence:.none)
    }

}

extension PKCS12.PKCS12Entry {
    public func createURLCredential(persistence: URLCredential.Persistence = .none) -> URLCredential {
        var certificates: [SecCertificate]? {
            let certs = self.certificateChainExcludingIdentityCert
            return certs.isEmpty ? nil : certs
        }
        
        return URLCredential(identity: self.identity, certificates: certificates, persistence: persistence)
    }
}
