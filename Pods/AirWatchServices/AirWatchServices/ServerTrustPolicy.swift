//
//  ServerTrustPolicy.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import Foundation


/**
    This file is a binding contract between AirWatchServices and its API calling layer for handling
    server trust. It is merely a thin wrapper around server trust interfaces in `AWNetwork`.
 */

public protocol ServerTrustPolicyBinder {
    /**
     1. Verify whether the host is pinned or not
     2. Return proper trust policy or nil if host is not pinned
     */
    func serverTrustPolicyForHost(_ host: String) -> AWServices.ServerTrustPolicy?
}


/**
 A wrapper to `ServerTrustPolicy` from `AWNetwork`
 */
extension AWServices {

    public enum ServerTrustPolicy {
        case performDefaultEvaluation(validateHost: Bool)
        case pinCertificates(certificates: [SecCertificate], validateCertificateChain: Bool, validateHost: Bool)
        case pinPublicKeys(publicKeys: [SecKey], validateCertificateChain: Bool, validateHost: Bool)
        case disableEvaluation
        case customEvaluation((_ serverTrust: SecTrust, _ host: String) -> Bool)
        
        public func evaluateServerTrust(_ serverTrust: SecTrust, isValidForHost host: String) -> Bool {
            var ctlServerTrustPolicy: CTLServerTrustPolicy? = nil
            switch self {
            case let .performDefaultEvaluation(validateHost):
                ctlServerTrustPolicy = .performDefaultEvaluation(validateHost: validateHost)
                break
            case let .pinCertificates(certificates, validateCertificateChain, validateHost):
                ctlServerTrustPolicy = .pinCertificates(certificates: certificates,
                                                        validateCertificateChain: validateCertificateChain,
                                                        validateHost:validateHost)
                break
            case let .pinPublicKeys(publicKeys, validateCertificateChain, validateHost):
                ctlServerTrustPolicy = .pinPublicKeys(publicKeys: publicKeys,
                                                      validateCertificateChain: validateCertificateChain,
                                                      validateHost: validateHost)
                break
            case .disableEvaluation:
                ctlServerTrustPolicy = .disableEvaluation
                break
            case let .customEvaluation(serverTrust):
                ctlServerTrustPolicy = .customEvaluation(serverTrust)
                break
                
            }
            return ctlServerTrustPolicy!.evaluateServerTrust(serverTrust, isValidForHost: host)
        }
    }

}
