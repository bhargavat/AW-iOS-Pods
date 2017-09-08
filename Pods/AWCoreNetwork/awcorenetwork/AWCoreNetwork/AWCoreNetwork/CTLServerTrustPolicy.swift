//
//  CTLServerTrustPolicy.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Alamofire
import Foundation


/**
 */
public protocol CTLServerTrustPolicyBinder {
    /**
        1. Verify whether the host is pinned or not
        2. Return proper trust policy or nil if host is not pinned
     */
    func serverTrustPolicyForHost(_ host: String) -> CTLServerTrustPolicy?
}



/**
    A wrapper to ``ServerTrustPolicy`` from ``Alamofire``
 */
public enum CTLServerTrustPolicy {
    
    case performDefaultEvaluation(validateHost: Bool)
    
    case pinCertificates(certificates: [SecCertificate], validateCertificateChain: Bool, validateHost: Bool)
    
    case pinPublicKeys(publicKeys: [SecKey], validateCertificateChain: Bool, validateHost: Bool)
    
    case disableEvaluation
    
    case customEvaluation((_ serverTrust: SecTrust, _ host: String) -> Bool)

    public func evaluateServerTrust(_ serverTrust: SecTrust, isValidForHost host: String) -> Bool {
        
        switch self {
        case let .performDefaultEvaluation(validateHost):
            return ServerTrustPolicy
                .performDefaultEvaluation(validateHost: validateHost)
                .evaluate(serverTrust, forHost: host)
    
        case let .pinCertificates(certificates, validateCertificateChain, validateHost):
            return ServerTrustPolicy
                .pinCertificates(certificates: certificates, validateCertificateChain: validateCertificateChain, validateHost:validateHost)
                .evaluate(serverTrust, forHost: host)
            
        
        case let .pinPublicKeys(publicKeys, validateCertificateChain, validateHost):
            return ServerTrustPolicy
                .pinPublicKeys(publicKeys: publicKeys, validateCertificateChain: validateCertificateChain, validateHost: validateHost)
                .evaluate(serverTrust, forHost: host)
        
        case .disableEvaluation:
            return ServerTrustPolicy
                .disableEvaluation
                .evaluate(serverTrust, forHost: host)
        
        case let .customEvaluation(customEvaluation):
            return ServerTrustPolicy
                .customEvaluation(customEvaluation)
                .evaluate(serverTrust, forHost: host)
        }
    }
}
