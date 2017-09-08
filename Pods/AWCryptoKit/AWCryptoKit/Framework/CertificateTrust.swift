//
//  CertificateTrust.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


public protocol CertificateTrustValidator {
    
    var trust: SecTrust { get }
    var keyPair: SecurityKeyPair? { get }

    init?(certificate: Certificate)
    
    static func validateTrust(_ certificate: Certificate, anchorCertificate: Certificate?) -> Bool
    static func validateTrust(_ certificateChain: [Certificate], anchorCertificate: Certificate?) -> Bool
}

extension CertificateTrustValidator {
    public var keyPair: SecurityKeyPair? {
        if let publicKey = SecTrustCopyPublicKey(trust) {
            let keyPair = SecurityKeyPair(publicKey: publicKey, privateKey: nil)
            return keyPair
        }
        return nil
    }

    public static func validateTrust(_ certificate: Certificate, anchorCertificate: Certificate? = nil) -> Bool {
        return validateTrust([certificate], anchorCertificate: anchorCertificate)
    }
    
    public static func validateTrust(_ certificateChain: [Certificate], anchorCertificate: Certificate? = nil) -> Bool {
        assert(certificateChain.count > 0, "Expected non-empty certificate chain to validate trust of.")
        
        var serverTrust: SecTrust?
        let serverTrustRef = withUnsafeMutablePointer(to: &serverTrust, { $0 })
        
        var certificates: [SecCertificate] = []
        for currentCert in certificateChain {
            certificates.append(currentCert.certificate)
        }
        
        let statusTrust = SecTrustCreateWithCertificates(certificates as CFTypeRef, [SecPolicyCreateBasicX509()] as CFTypeRef, serverTrustRef)
        guard (statusTrust == noErr && serverTrust != nil)
            else {
                log(error:"Can not create trust: \(statusTrust.description)")
                return false
        }
        
        guard let trust = serverTrust else {
            log(error:"Can not unwrap trust: \(statusTrust.description)")
            return false
        }
                
        if let anchorCert = anchorCertificate {
            let certArray = [anchorCert.certificate]
            let statusAnchor = SecTrustSetAnchorCertificates(trust, certArray as CFArray)
            guard statusAnchor == noErr else {
                log(error:"Can not set anchor certificate")
                return false
            }
        }
        
        var trustResult: SecTrustResultType = SecTrustResultTypeConverter.invalid.toSecTrustResultType()
        let trustResultRef = withUnsafeMutablePointer(to: &trustResult, { $0 })
        let statusResult = SecTrustEvaluate(trust, trustResultRef)
        guard statusResult == errSecSuccess else {
            log(error:"Failed to evaluate the trust: \(statusResult.description)")
            return false
        }
        
        if SecTrustResultTypeConverter(trustResult) == SecTrustResultTypeConverter.proceed ||
            SecTrustResultTypeConverter(trustResult) == SecTrustResultTypeConverter.unspecified {
            log(info:"Given certificate can be trusted based on anchor certificate")
            return true
        }
        
        log(info:"Added cert can't be verified with anchor certificate")
        return false
    }


}

public final class CertificateTrust: CertificateTrustValidator {
    public fileprivate(set) var trust: SecTrust

    public convenience init?(certificate: Certificate) {
        self.init(certificates: [certificate])
    }
    
    /// Used to create a Certificate Trust object using a certificate chain.
    public init?(certificates: [Certificate]) {
        var tempTrust: SecTrust? = nil
        let trustRef = withUnsafeMutablePointer(to: &tempTrust, { $0 })
        
        var certArray: [SecCertificate] = []
        for cert in certificates {
            certArray.append(cert.certificate)
        }
        
        let trustStatus = SecTrustCreateWithCertificates(certArray as CFTypeRef, [SecPolicyCreateBasicX509()] as CFTypeRef, trustRef)
        guard trustStatus == noErr
            else {
                log(error:"Can not create trust: \(trustStatus.description)")
                return nil
        }
        
        guard tempTrust != nil
            else {
                log(error:"Empty trust")
                return nil
        }
        
        trust = tempTrust!
    }
    
    public func validateTrust() -> Bool {
        
        var trustResult: SecTrustResultType = SecTrustResultTypeConverter.invalid.toSecTrustResultType()
        let trustResultRef = withUnsafeMutablePointer(to: &trustResult, { $0 })
        let statusResult = SecTrustEvaluate(trust, trustResultRef)
        guard statusResult == errSecSuccess else {
            log(error:"Failed to evaluate the trust: \(statusResult.description)")
            return false
        }
        
        if SecTrustResultTypeConverter(trustResult) == SecTrustResultTypeConverter.proceed ||
            SecTrustResultTypeConverter(trustResult) == SecTrustResultTypeConverter.unspecified {
            log(info:"Given certificate can be trusted based on anchor certificate")
            return true
        }
        
        log(info:"Added cert can't be verified with anchor certificate")
        return false
    }
}

public enum SecTrustResultTypeConverter : UInt32
{
    case invalid
    case proceed
    case confirm    // Deprecated
    case deny
    case unspecified
    case recoverableTrustFailure
    case fatalTrustFailure
    case otherError
    
    init(_ val: SecTrustResultType)
    {
        #if swift(>=2.3)
            self = SecTrustResultTypeConverter(rawValue: val.rawValue) ?? .invalid
        #else
            self = SecTrustResultTypeConverter(rawValue: val) ?? .Invalid
        #endif
    }
    
    func toSecTrustResultType() -> SecTrustResultType
    {
        #if swift(>=2.3)
            return SecTrustResultType(rawValue: self.rawValue) ?? SecTrustResultType.invalid
        #else
            return UInt32(self.rawValue)
        #endif
    }
}
