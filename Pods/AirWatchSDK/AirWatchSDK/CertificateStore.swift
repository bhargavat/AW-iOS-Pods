//
//  CertificateStore.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCrypto
import AWServices
import AWStorage
import AWCMWrapper

public typealias certRetrieveCompletionHandler = (_ success: Bool, _ credentials: [String: AnyObject]?, _ error: NSError?) -> Void

internal enum CertficateStoreKeys : String {
    case CertificateData          = "AWCertificateInfoCertificateData"
    case CertificatePassword      = "AWCertificateInfoCertPassword"
}

internal class CertificateStore: NSObject {
    
    fileprivate var context: SDKContext
    var deviceServices: DeviceServices?
    var allowedSites: [String]?

    init(with context: SDKContext) {
        self.context = context
        self.deviceServices = context.deviceServices
        super.init()
    }
    

    internal static func isCertificateValid(certificateData: Data, certificatePassword: String) -> Bool {
        
        do {
            let certificate = try CertificateFormat.pkcs12(certificatePassword).parse(certificateData: certificateData)
            let certData = SecCertificateCopyData(certificate) as Data
            if let x509Pub: AWX509Wrapper = AWX509Wrapper(certificateData: certData) {
                let certificateIsValid = x509Pub.isValid
                log(info: "Certificate is expired: \(certificateIsValid == false)")
                return certificateIsValid
            }
            log(warning: "incorrect certificate format")
            return false
        } catch let error {
            log(warning: "certififcate parse failed with error:\(error)")
            return false
        }
    }
    //add new pair of certificateIssuer, cert or update existing one
    func saveCertDictionary(_ dictionary: [String: AnyObject], forCertificateIssuer certificateIssuer: String) {

        guard dictionary.count > 0 else {
            log(error: "not saving, empty cert dict")
            return
        }

        var dict: [String: AnyObject] = Dictionary()
        if let retrieved = self.retrieveIssuerCertMapping() {
            dict = retrieved
        }
        dict[certificateIssuer] = dictionary as AnyObject?
        self.saveCertDictionary(dict)
            
    }
    
    func retrieveIssuerCertMapping() -> [String: AnyObject]? {
        let certDict = self.context.identity as? [String: AnyObject]
        return certDict
    }

    fileprivate func saveCertDictionary(_ certDictionary: [String: AnyObject]) {
        let dict = certDictionary as NSDictionary
        self.context.identity = dict;
    }
    
    func clearCert() {
        self.context.identity = nil
    }


    func certDictforCertificateIssuer(_ certificateIssuer: String) -> [String: AnyObject]? {
        guard certificateIssuer.characters.count > 0 else {
            return nil
        }
        /// dictionary mapping guid to certs
        let certDict = self.retrieveIssuerCertMapping()
        return certDict?[certificateIssuer] as? [String: AnyObject]
    }

    func certificateIssuerExists(_ certificateIssuerId: String) -> Bool {
        guard let certDict = self.retrieveIssuerCertMapping() else {
            return false
        }
        
        guard let certificateIssuerDictionary = certDict[certificateIssuerId] as? [String : AnyObject],
            let certData = certificateIssuerDictionary[CertficateStoreKeys.CertificateData.rawValue] as? Data,
            let certPassword = certificateIssuerDictionary[CertficateStoreKeys.CertificatePassword.rawValue] as? String
            else {
            log(error: "incorrect certificate format stored")
            return false
        }
        
        //checking certificate validity
        guard CertificateStore.isCertificateValid(certificateData: certData, certificatePassword: certPassword) else {
            log(info: "certificate stored for issuerID:\(certificateIssuerId) is not valid")
            return false
        }
        return true
    }

    func certDictforHost(_ host: String) -> [String: AnyObject]? {
        /// if keychain is shared, get from certStore
        guard host.characters.count > 0 else {
            return nil
        }

        if let certIssuerId = self.issuerIdForHost(host) {
            return self.certDictforCertificateIssuer(certIssuerId)
        }
        return nil
    }

    // TODO: need to change the implemetation in case of multiple certificates (right now only one certificate  is supported)
    func fetchCertificates(forIdentity identityPayload: IdentityPayload, completionBlock: @escaping certRetrieveCompletionHandler) {

        guard let token = identityPayload.issuerToken, let guid = identityPayload.guid else {
                log(error: "Missing required values from Identity Payload in order to fetch certificates")
                completionBlock(false, nil, nil)
                return
        }

        log(verbose: "Received GUID: \(guid)")

        guard self.certificateIssuerExists(guid) == false else {
            log(verbose: "no need to fetch, certificates already present")
            guard let certDict = self.retrieveIssuerCertMapping() else {
                log(verbose: "No identity in the context")
                completionBlock(false, nil, nil)
                return
            }
            let credentials = [
                "certificateDictionary": certDict as AnyObject
            ]
            
            completionBlock(true, credentials, nil)
            return
        }

        guard let deviceServices = self.deviceServices else {
            log(verbose: "Can't fetch new certificates, missing required device services")
            completionBlock(false, nil, nil)
            return
        }

        deviceServices.fetchCertificates(guid, token: token, completionHandler: { /*[weak self]*/ (certInfo, error) in
            // TODO: Implement the use of the certInfo response.
//            guard let weakSelf = self else {
//                return
//            }

            if let certInfo = certInfo {
                log(info: "Certificate saved")
                let certDict = [CertficateStoreKeys.CertificateData.rawValue :certInfo.certificatateData, CertficateStoreKeys.CertificatePassword.rawValue:certInfo.certificatatePassword] as [String : Any]
                self.saveCertDictionary(certDict as [String: AnyObject], forCertificateIssuer: guid)
            }

            if let error = error {
                log(error: "error = \(error), retreiving cert for guid \(guid)")
            }

            var credentials: [String: AnyObject] = [:]
            var isSuccess = false
            let issuerCertMap = self.retrieveIssuerCertMapping()
            if let count = issuerCertMap?.count, count > 0 {
                credentials["certificateDictionary"] = issuerCertMap as AnyObject?
                isSuccess = true
            }
            completionBlock(isSuccess, credentials, error)
        })

    }


    func certExistsForHost(_ host: String) -> Bool {
        guard let _ = self.issuerIdForHost(host) else {
            return false
        }
        return true
    }

    //if returns nil, no cert exists
    func issuerIdForHost(_ host: String) -> String? {
        //For now only single guid (cert) is supported
        var certIssuerId: String? = self.context.SDKProfile?.identityPayload?.guid
        guard host.characters.count > 0 else {
            return nil
        }

        // Host to Issuer mapping
        // Need Allowed Sites from Authentication Payload
        if let currentAllowedSites = allowedSites, currentAllowedSites.count  > 0 {
            if !self.isAllowHost(host, InIAallowedSites: currentAllowedSites) {
                certIssuerId = nil
            }
        }
        
        //ISDK-169094: issuer id can be blank if it has been already fetched by Anchor.
        //Try to find cert issuer in stored certificate structure. If present, return it.
        if let issuerId = certIssuerId, issuerId.characters.count <= 0 || certIssuerId == nil {
            if let certDict: [String: AnyObject] = self.retrieveIssuerCertMapping() {
                for certifcateIssuerId in certDict.keys {
                    let certificateIssuerDictionary = certDict[certifcateIssuerId] as? [String : AnyObject]
                    if certificateIssuerDictionary != nil {
                        log(info: "Returning stored certificate issuerId while payload doesn't have it")
                        certIssuerId = certifcateIssuerId
                        //we break once we found a valid certificate issuer id, This relies on the assumption 
                        //we have only one correct entry stored
                        break
                    }
                    else {
                        log(warning: "Invalid object stored in certificate dictionary found")
                    }
                }
            }
        }
        return certIssuerId
    }

    func credentialExistsForHost(_ host: String) -> Bool {
        guard let currentAllowedSites = allowedSites else {
            return true
        }

        if currentAllowedSites.count  > 0 {
            return self.isAllowHost(host, InIAallowedSites: currentAllowedSites)
        }

        return true
    }

    func isAllowHost(_ host: String, InIAallowedSites allowedSites: Array<String>) -> Bool {
        guard host.characters.count > 0 && allowedSites.count > 0 else {
            return false
        }

        for domain in allowedSites {
            if domain.characters.count > 0 {
                if domain.urlRegexMatches(host) { // FIXME: Need to change this method name to urlDomainMatches(String)
                    return true
                }
            }

        }
        return false
    }

    /// this method assumes just one certificate request
    func certificateRequestInfo() -> [String: AnyObject]? {
        guard let guID = self.context.SDKProfile?.identityPayload?.guid, let certDictionaryMap = self.retrieveIssuerCertMapping() else {
            return nil
        }

        var thumbPrint: String? = nil

        if let certDict = certDictionaryMap[guID] as? [String: AnyObject], let certData = certDict[CertficateStoreKeys.CertificateData.rawValue] {
            var certPwd = certDict[CertficateStoreKeys.CertificatePassword.rawValue] as? String
            if certPwd?.characters.count == 0 {
                certPwd = nil
            }
            thumbPrint = thumbPrintForCertificate(certData as! Data, certPass: certPwd)
        }

        let issuerIdThumbprint = ["certificateIssuerId": guID, "Thumbprint": thumbPrint ?? ""]

        return issuerIdThumbprint as [String: AnyObject]?
    }

    // TODO: This Method should probably be private as it is only used in this class as a helper method, But need to verify before making the change.
    func thumbPrintForCertificate(_ certData: Data, certPass: String?) -> String? {
        var thumbPrint: String? = nil
        if let password = certPass {
            if let properCert = try? Certificate(certificateData:certData, format: .pkcs12(password)) {
                thumbPrint = properCert.SHA1Thumbprint
            }
        } else {
            if let shaData: Data = certData.sha1 {
                thumbPrint = shaData.hexadecimalString
            }
        }
        return thumbPrint
    }

    // TODO: Implement following methods as needed in future Cert Store uses.
//    //this method assumes just one certificate request
//    func certificateRequestQueryString() -> String {}
//
//    func newFetchRequiredForCertInfo(certInfo: [String: AnyObject]) -> Bool {}
//
//    //only gets reset when new fetch cert call is made
//    class func attemptedWithCertififcateEndPoint() -> Bool {}
//
//    class func setAttemptedWithCertificateEndPoint(attempted: Bool) {}

}
// TODO: Remove this extension when PR to CorePlatform helpers is merged.
extension String {
    func urlRegexMatches( _ request: String) -> Bool {
        let schemeRegex = "((https?|ftps?)://)?"
        let wildcard = "*"
        let domainRegex = "([\\.\\-0-9a-zA-Z])*"

        var preprocessedURL = self
        if !(preprocessedURL.hasPrefix("http") || preprocessedURL.hasPrefix("ftp")) {
            preprocessedURL = schemeRegex + preprocessedURL
        }

        preprocessedURL = preprocessedURL.replacingOccurrences(of: wildcard, with: domainRegex)

        /// Add Regex start and end markers
        preprocessedURL = "^\(preprocessedURL)$"

        let regex = try? NSRegularExpression(pattern: preprocessedURL, options: NSRegularExpression.Options.caseInsensitive)

        if let matches = regex?.numberOfMatches(in: request, options: NSRegularExpression.MatchingOptions.anchored, range: NSMakeRange(0, request.characters.count)) {
            return matches > 0
        }
        return false
    }
}
