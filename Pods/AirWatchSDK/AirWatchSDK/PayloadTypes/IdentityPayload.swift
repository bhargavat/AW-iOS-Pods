//
//  IdentityPayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc(AWIdentityPayload)
internal class IdentityPayload: ProfilePayload {

    /// The Certificate Issuer
    public fileprivate (set) var guid: String?
    /// one time token
    public fileprivate (set) var issuerToken: String?

    /// For constructing this payload in UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        let infoDictionary = self.toDictionary()
        self.guid = infoDictionary[IdentityPayloadConstants.kCertificateGuid] as? String
        self.issuerToken = infoDictionary[IdentityPayloadConstants.kIssuerToken] as? String
    }

    override public class func payloadType() -> String {
        return IdentityPayloadConstants.kIdentityPayloadType
    }
}
