 //
//  HMACAuthentication.swift
//  SDKLite_Authentication
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWNetwork
import AWCrypto
import Foundation
import AWHelpers

public extension NSMutableURLRequest {

    public var signatureMethod: String? {
        get {
            return URLProtocol.property(forKey: HTTPConstants.kHTTPSignatureMethod, in: self as URLRequest) as? String
        }

        set (method) {
            if (method != nil) {
                URLProtocol.setProperty(method as AnyObject, forKey: HTTPConstants.kHTTPSignatureMethod, in: self)
            } else {
                URLProtocol.removeProperty(forKey: HTTPConstants.kHTTPSignatureMethod, in: self)
            }
        }
    }
}

public protocol HMACAuthorizer: CTLAuthorizationProtocol {
    var hmacKey: Data { get }
    var authGroup: String { get }
    var deviceId: String { get }
}

extension HMACAuthorizer {
    
    public func authorize(request: NSMutableURLRequest?, on: DispatchQueue?) -> CTLTask<Void>? {
        guard let request = request else {
            return nil
        }

        guard hmacKey.count > 0 else {
            return nil
        }

        let shellTask = CTLTask<Void>()

        let workerQueue = on ?? DispatchQueue.global(qos: DispatchQoS.QoSClass.default)

        _ = Task<Void>.performWork(on: workerQueue) {
            let requestSigned = self.signRequest(request)
            //MARK: TODO: Construct result and error objects
            if (requestSigned) {
                shellTask.completeWithValue()
            } else {
                shellTask.failWithError(NSError(domain: "HMACAuthentication", code: 1, userInfo: nil))
            }
        }

        return shellTask
    }

    public func signRequest(_ request: NSMutableURLRequest) -> Bool {

        if (request.signatureMethod == nil) {
            /// ISDK-168702 Default signature method HMAC-SHA256
            request.signatureMethod = AuthenticationConstants.kAWSignatureSHA256
        }
        if (request.value(forHTTPHeaderField: HTTPConstants.kHTTPHeaderContentType) == nil &&
            request.httpMethod.uppercased() == "POST") {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: HTTPConstants.kHTTPHeaderContentType)
        }

        request.setValue(AuthenticationConstants.kAWVer1, forHTTPHeaderField: AuthenticationConstants.kAWSignatureVersion)
        request.setValue(AuthenticationConstants.kAWAuthRealmDevice, forHTTPHeaderField: AuthenticationConstants.kAWAuthRealm)

        if (request.value(forHTTPHeaderField: AuthenticationConstants.kAWAuthGroupid) == nil) {
            request.setValue((self.authGroup), forHTTPHeaderField: AuthenticationConstants.kAWAuthGroupid)
        }

        if (request.value(forHTTPHeaderField: AuthenticationConstants.kAWAuthDeviceuid) == nil) {
            request.setValue((self.deviceId), forHTTPHeaderField: AuthenticationConstants.kAWAuthDeviceuid)
        }
        if (request.value(forHTTPHeaderField: HTTPConstants.kHTTPHeaderDate) == nil) {
            request.setValue(DateFormatter.GMTDateFormatterPOSIXLocale.string(from: Date()), forHTTPHeaderField: HTTPConstants.kHTTPHeaderDate)
        }

        /// 1. Append header values in the list. If blank, just append new line.
        let headerList = [HTTPConstants.kHTTPHeaderContentEncoding,
                          HTTPConstants.kHTTPHeaderContentLanguage,
                          HTTPConstants.kHTTPHeaderContentType,
                          HTTPConstants.kHTTPHeaderDate,
                          HTTPConstants.kHTTPHeaderIfModifiedSince,
                          HTTPConstants.kHTTPHeaderIfMatch,
                          HTTPConstants.kHTTPHeaderIfNoneMatch,
                          HTTPConstants.kHTTPHeaderIfUnModfifedSince,
                          HTTPConstants.kHTTPHeaderRange]
        var stringToSign = "" + request.httpMethod + "\n"
        stringToSign = headerList.reduce(stringToSign, { (appendedString: String, currentHeader: String) -> String in
            return appendedString + (request.value(forHTTPHeaderField: currentHeader) ?? "") + "\n"
        })

        /// 2. Filter canonicalized headers.
        stringToSign = (request.allHTTPHeaderFields?.filter({
            return $0.0.hasPrefix("aw-") && !$0.0.hasPrefix("aw-auth-")
        }).map({
            return ($0.0).lowercased() + ":" + $0.1
        }).sorted().reduce(stringToSign, {
            return $0 + $1 + "\n"
        }))!

        /// 3. Canonicalized resource
        if let url = request.url, let scheme = url.scheme {
            var canonicalResource = url.absoluteString
            canonicalResource = canonicalResource.replacingOccurrences(of: scheme + "://", with: "")
            if let query = request.url?.query {
                canonicalResource = canonicalResource.replacingOccurrences(of: query, with: "")
            }
            canonicalResource = canonicalResource.replacingOccurrences(of: "?", with: "")
            stringToSign += canonicalResource.lowercased()
        }

        /// 4. Body data
        var signedBody: String? = nil
        if let httpBody = request.httpBody {
            if (request.signatureMethod == AuthenticationConstants.kAWSignatureSHA1) {
                signedBody = httpBody.sha1?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
            } else if (request.signatureMethod == AuthenticationConstants.kAWSignatureSHA256) {
                signedBody = httpBody.sha256?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
            }
        } else if let fileHash = request.value(forHTTPHeaderField: AuthenticationConstants.kAWFileHashHeader) {
            signedBody = fileHash
        }

        if let signedBody = signedBody {
            stringToSign += signedBody
        }

        log(debug: "The request's HTTP Headers Fields for signing HMAC: \(String(describing: request.allHTTPHeaderFields))")
        log(debug: "Signing HMAC Key: \(self.hmacKey)")
        var signature: String
        guard let dataToSign = stringToSign.data(using: String.Encoding.utf8) else {
            log(error: "string failed to convert to data")
            return false
        }
        if (request.signatureMethod == AuthenticationConstants.kAWSignatureSHA1) {
            request.setValue("HMAC-SHA1", forHTTPHeaderField: AuthenticationConstants.kAWSignatureMethod)
            signature = dataToSign.base64HMACSignature(Digest.sha1, key: self.hmacKey)
        } else if (request.signatureMethod == AuthenticationConstants.kAWSignatureSHA256) {
            request.setValue("HMAC-SHA256", forHTTPHeaderField: AuthenticationConstants.kAWSignatureMethod)
            signature = dataToSign.base64HMACSignature(Digest.sha256, key: self.hmacKey)
        } else {
            log(error: "Unknown signature method")
            return false
        }

        log(debug: "Signature (\(stringToSign)): \(signature)")

        request.setValue((self.deviceId) + ":" + signature, forHTTPHeaderField: HTTPConstants.kHTTPHeaderSignature)
        return true
    }

 }


 public class DeviceServicesHMACAuthorizer: HMACAuthorizer {

    public var hmacKey: Data
    public var authGroup: String
    public var deviceId: String

    public init?(deviceId: String, authGroup: String, hmac: Data) {

        guard deviceId.characters.count > 0 else {
            return nil
        }

        guard authGroup.characters.count > 0 else {
            return nil
        }

        guard hmac.count > 0 else {
            return nil
        }

        self.deviceId = deviceId
        self.authGroup = authGroup
        self.hmacKey = hmac
    }

    public convenience init?(config: UserAuthConfig?, hmac: String) {
        guard let givenDeviceId = config?.deviceId,
            let givenAuthGroup = config?.authenticationGroup else {
            return nil
        }

        guard let givenKey  = hmac.data(using: String.Encoding.utf8) else {
            return nil
        }

        self.init(deviceId: givenDeviceId, authGroup: givenAuthGroup, hmac: givenKey)
    }
    
    public func refreshAuthorization(completion: @escaping (CTLAuthorizationProtocol?, NSError?) -> Void) {
        completion(nil, nil);
    }

}
