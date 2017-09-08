//
//  AuthenticationConstants.swift
//  SDKLite_Authentication
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

class AuthenticationConstants {
    // Auth Endpoint constant
    static let kAWAuthEndpoint = "/deviceservices/AuthenticationEndpoint.aws"
    
    // http body/header constants
    static let kAWAuthUsernameKey = "Username"
    static let kAWAuthPasswordKey = "Password"
    static let kAWAuthActivationCodeKey = "ActivationCode"
    
    static let kAWAuthAuthTokenKey = "AuthorizationCode"
    
    static let kAWAuthUdidKey = "Udid"
    static let kAWAuthDeviceTypeKey = "DeviceType"
    static let kAWAuthBundleIdKey = "BundleId"
    static let kAWAuthRequestingAppKey = "RequestingApp"
    static let kAWAuthAuthTypeKey = "AuthenticationType"
    static let kAWAuthAuthGroupKey = "AuthenticationGroup"
    
    static let kAWAuthRedirectUrlKey = "RedirectUrl"
    
    // http response constants
    static let kAWAuthResponseStatusCodeKey = "StatusCode"
    static let kAWAuthResponseAWHMACKey = "AWHMACKey"
    static let kAWAuthResponseAuthorizationTokenKey = "AWAuthenticationToken"
    static let kAWAuthResponseAuthenticationCertificateKey = "AWAuthenticationCertificate"
    static let kAWAuthResponseUserIdKey = "UserId"
    static let kAWAuthResponseUsernameKey = "Username"
    static let kAWAuthResponseEulaKey = "IsEulaAcceptanceRequired"
    
    static let kAWAuthResponseHeaderAWVersionKey = "x-aw-version"

    // http digest signature constants
    static let kAWSignatureVersion = "AW-AUTH-SIGNATURE-VERSION"
    static let kAWSignatureMethod = "AW-AUTH-SIGNATURE-METHOD"
    static let kAWAuthRealm = "AW-AUTH-REALM"
    static let kAWAuthRealmDevice =	"device"
    static let kAWVer1 = "1"
    static let kAWAuthDeviceuid	= "aw-device-uid"
    static let kAWAuthGroupid = "aw-auth-group-id"
    static let kAWSignatureSHA1 = "aw-sha1"
    static let kAWSignatureSHA256 = "aw-sha256"
    static let kAWFileHashHeader = "aw-content-hash"
}

class HTTPConstants {
    // http header keys
    static let kHTTPHeaderContentType = "Content-Type"
    static let kHTTPHeaderAccept = "Accept"
    static let kHTTPHeaderContentLanguage = "Content-Language"
    static let kHTTPHeaderContentEncoding = "Content-Encoding"
    static let kHTTPHeaderIfUnModfifedSince	= "If-Unmodified-Since"
    static let kHTTPHeaderIfMatch =	"If-Match"
    static let kHTTPHeaderIfModifiedSince = "If-Modified-Since"
    static let kHTTPHeaderIfNoneMatch = "If-None-Match"
    static let kHTTPHeaderRange	= "Range"
    static let kHTTPHeaderDate = "DATE"
    static let kHTTPHeaderSignature = "AUTHORIZATION";
    
    // http header constants
    static let kHTTPHeaderAppJson = "application/json"
    
    // http method constants
    static let kHTTPMethodPost = "POST"
    static let kHTTPMethodGet = "GET"
    static let kHTTPMethodPut = "PUT"
    static let kHTTPMethodDelete = "DELETE"
    static let kHTTPMethodHead = "HEAD"

    /// additional customized properties
    static let kHTTPSignatureMethod = "SignatureMethod"
}
