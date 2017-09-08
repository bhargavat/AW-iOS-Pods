//
//  CertificatePayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWTunnel
/**
 * @brief		Analytics payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the certificate group of an application profile.
 * @version     6.0
 */
@objc(AWSDKCertificatePayload)
internal class SDKCertificatePayload: ProfilePayload, CertificatePayload {

    /** The certificate's data. */
    public fileprivate (set) var certificateData: Data?

    /** The name of the certificate. */
    public fileprivate (set) var certificateName: String?

    /** The password of the certificate. */
    public fileprivate (set) var certificatePassword: String?

    /** The thumbprint of the certificate. */
    public fileprivate (set) var certificateThumbprint: String?

    /** The type of the certificate. */
    public fileprivate (set) var certificateType: String?

//MARK: - Lifecycle

    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override required public init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)

        self.certificateData = dictionary[CertificatePayloadConstants.kCertificatePayloadData] as? Data
        self.certificateName = "V2 Certificate Name"
        self.certificatePassword = dictionary[CertificatePayloadConstants.kCertificatePayloadPassword] as? String
        self.certificateThumbprint = dictionary[CertificatePayloadConstants.kCertificatePayloadThumbprint] as? String
        self.certificateType = dictionary[CertificatePayloadConstants.kCertificatePayloadCertificateType] as? String
    }

//MARK: - Public Methods
    override public class func payloadType() -> String {
        return CertificatePayloadConstants.kCertificatePayloadType
    }
}
