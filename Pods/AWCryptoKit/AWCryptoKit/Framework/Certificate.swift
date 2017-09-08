//
//  Certificate.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import Security
import AWError
import AWLog

public enum CertificateFormat {
    case pem, der, pkcs12(String)

    public func parse(certificateData: Data) throws -> SecCertificate {
        switch self {
        case .der:
            return try parseDER(certificateData: certificateData)

        case .pem:
            return try parsePEM(certificateData: certificateData)

        case .pkcs12(let password):
            return try parsePKCS12(data: certificateData, password: password)
        }
    }
    
    private func parsePKCS12(data: Data, password: String) throws -> SecCertificate {
        guard let pkcs12 = PKCS12(p12Data: data, password: password),
            let entry = pkcs12.entries.first,
            let certificate = entry.certificate else {
            throw  AWError.SDK.CryptoKit.Certificate.invalidCertificate
        }

        return certificate
    }
    
    private func parseDER(certificateData: Data) throws -> SecCertificate {
        let loadedCertificate = SecCertificateCreateWithData(kCFAllocatorDefault, certificateData as CFData)
        guard loadedCertificate != nil else {
            throw  AWError.SDK.CryptoKit.Certificate.invalidCertificate
        }
        
        return loadedCertificate!
    }

    private func parsePEM(certificateData: Data) throws -> SecCertificate {
        let certificateContent = String(data: certificateData, encoding: String.Encoding.utf8)
        var certLines = certificateContent?.components(separatedBy: CharacterSet.newlines)

        if certLines?.first == "-----BEGIN CERTIFICATE-----" {
            certLines?.removeFirst()
        }

        if certLines?.last == "-----END CERTIFICATE-----" {
            certLines?.removeLast()
        }

        let baseEncoded64Certificate = certLines?.joined(separator: "")
        guard baseEncoded64Certificate != nil
            else { throw  AWError.SDK.CryptoKit.Certificate.invalidCertificate }

        let base64DecodedData = Data(base64Encoded: baseEncoded64Certificate!,
                                       options: Data.Base64DecodingOptions.ignoreUnknownCharacters)
        guard base64DecodedData != nil
            else { throw  AWError.SDK.CryptoKit.Certificate.invalidCertificate }

        let loadedCertificate = SecCertificateCreateWithData(kCFAllocatorDefault, base64DecodedData! as CFData)
        guard loadedCertificate != nil
            else { throw  AWError.SDK.CryptoKit.Certificate.invalidCertificate }

        return loadedCertificate!
    }
}

public final class Certificate {

    let certificate: SecCertificate

    fileprivate func thumbprint(_ digest: Digest) -> String? {
        let data = SecCertificateCopyData(certificate) as Data
        return digest.digest(data)?.hexString
    }

    public var SHA1Thumbprint: String? {
        return self.thumbprint(Digest.sha1)
    }

    public var SHA256Thumbprint: String? {
        return self.thumbprint(Digest.sha256)
    }

    public var keyPair: SecurityKeyPair? {
        return CertificateTrust(certificate: self)?.keyPair
    }

    public func validate(withAnchor anchor: Certificate) -> Bool {
        return CertificateTrust.validateTrust(self, anchorCertificate: anchor)
    }

    public init(filePath: String, format: CertificateFormat) throws {
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath))
        guard let certificateData = data
            else { throw  AWError.SDK.CryptoKit.Certificate.emptyCertificateFile }

        self.certificate = try format.parse(certificateData: certificateData)
    }

    public init(certificateData: Data, format: CertificateFormat) throws {
        self.certificate = try format.parse(certificateData: certificateData)
    }
    
    public init(certificate: SecCertificate) {
        self.certificate = certificate
    }
    
}


public final class PKCS12 {
    
    public final class PKCS12Entry {
        public let identity: SecIdentity
        public let trust: SecTrust

        public var certificate: SecCertificate? {
            var certificate: SecCertificate? = nil
            _ = SecIdentityCopyCertificate(self.identity, &certificate)
            return certificate
        }

        public var certificateChain: [SecCertificate] {
            var certificateChain: [SecCertificate] = []
            let count = SecTrustGetCertificateCount(trust)
            for i in 0..<count {
                if let certificate = SecTrustGetCertificateAtIndex(trust, i as CFIndex) {
                    certificateChain.append(certificate)
                }
            }
            return certificateChain
        }
        
        public var certificateChainExcludingIdentityCert: [SecCertificate] {
            
            var certChain: [SecCertificate] = []
            let count = SecTrustGetCertificateCount(trust)

            var identityCertData : Data? = nil
            if let  identityCert = self.certificate {
                identityCertData = SecCertificateCopyData(identityCert) as Data
            }
            
            for i in 0..<count {
                if let certificate = SecTrustGetCertificateAtIndex(trust, i as CFIndex) {
                    
                    if let identityCertData = identityCertData, SecCertificateCopyData(certificate) as Data == identityCertData {
                        continue
                    }
                    certChain.append(certificate)
                }
            }
            return certChain
        }
        


        public init(identity: SecIdentity, trust: SecTrust) {
            self.identity = identity
            self.trust = trust
        }
        
    }

    public let entries: [PKCS12Entry]
    
    public init?(p12Data: Data, password: String) {
        
        let options:[String: AnyObject] = [String(kSecImportExportPassphrase): password as AnyObject]
        var items: CFArray? = nil
        let result = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
        guard result == errSecSuccess,
            let extractedItems = items as [AnyObject]?,
            extractedItems.count > 0 else {
            AWLogError("PKCS12 Import did not yield any certificates or identities")
            return nil
        }
        
        var pkcs12Entries: [PKCS12Entry] = []
        for certificateDict in extractedItems {
            if let identityDictionary = certificateDict as? [AnyHashable: AnyObject],
                let identity = identityDictionary[String(kSecImportItemIdentity)],
                let trust = identityDictionary[String(kSecImportItemTrust)] {
                let entry = PKCS12Entry(identity: identity as! SecIdentity, trust: trust as! SecTrust)
                pkcs12Entries.append(entry)
            }
        }
        self.entries = pkcs12Entries
    }
    
    public convenience init?(filePath: String, password: String) {
        let data = try? Data(contentsOf: URL(fileURLWithPath: filePath))
        guard let certificateData = data else {
            return nil
        }
        
        self.init(p12Data: certificateData, password: password)
    }
}
