//
//  SSLPinningCertificate.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc
public class SSLCertificatePinningConfiguration: NSObject {
    internal var domain: String?
    internal var certData: Data?
    internal var thumbPrint: String?
    internal var includeSubDomains: Bool?
    internal var strict: Bool?

    public override init() { }

    required public init(coder: NSCoder) {
        if let domain = coder.decodeObject(forKey: "domain") as? String {
            self.domain = domain
        }
        if let certData = coder.decodeObject(forKey: "certData") as? Data {
            self.certData = certData
        }
        includeSubDomains = coder.decodeBool(forKey: "includeSubDomains")
        strict = coder.decodeBool(forKey: "strict")
        if let thumbPrint = coder.decodeObject(forKey: "thumbprint") as? String {
            self.thumbPrint = thumbPrint
        }
    }

    internal func encode(with coder: NSCoder) {
        coder.encode(self.domain, forKey:"domain")
        coder.encode(self.certData, forKey:"certData")
        coder.encode(self.thumbPrint, forKey:"thumbprint")
        coder.encode(self.strict, forKey:"strict")
        coder.encode(self.includeSubDomains, forKey:"includeSubDomains")
    }
}
