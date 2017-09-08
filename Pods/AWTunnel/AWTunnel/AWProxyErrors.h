
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

/*! \file AWProxyErrors.h */

#import <Foundation/Foundation.h>

#ifndef __AWPROXYERRORS_H
#define __AWPROXYERRORS_H

/*! @constatnt Error domain for NSError values stemming from AWProxy */
#ifdef __cplusplus
extern "C" {
#endif

extern NSString *const AWProxyErrorDomain;
extern NSString *const AWSDKErrorDomain;


extern NSString *const AWRefetchMAGCertificate;
extern NSString *const AWMAGCertFetchFailureErrorCode;
extern NSString *const kAWSDKMAGErrorCodeKey;
    
enum
{
	/* Error codes returned from the MAG proxy headers */
    AWProxyErrorMAG407Unknown = 0,				// Unknown Error
    AWProxyErrorMAG407MissingHeader = 1,		// Some Headers like "Proxy-Authorization" are missing.
    AWProxyErrorMAG407WrongEncoding = 2,		// Few values like Signature, Scheme-Specific part are not base 64 encoded
    AWProxyErrorMAG407IDNotFound = 3,			// ID_FORMAT should contain encryption algo, uid and bundleid in a specific format. Failing, it would throw this error code.
    AWProxyErrorMAG407WrongALG = 4,				// Any encryption algorithm other than "cms1" will be rejected.
    AWProxyErrorMAG407EmptyCertChain = 5,		// If no certificate was found in the chain.
    AWProxyErrorMAG407SingleSigner = 6,			// If there are multiple signers are found in the certificate chain, then it would this error.
    AWProxyErrorMAG407SingleSignerCert = 7,		// If there are multiple certificate for Signers, MAG expects only one signer.
	AWProxyErrorMAG407InvalidSign = 8,			// If MAG is not able to verify the Signer, then it would throw this error.
	AWProxyErrorMAG407UntrustedIssuer = 9,		// If Signer Certificate is not trusted by MAG, then it would throw this error.
	AWProxyErrorMAG407MissingSignTime = 10,		// Signing time attribute not present to determine potential replay attack
	AWProxyErrorMAG407PotentialReplay = 11,		// If the time between signing and verification is more than the configure time.
	AWProxyErrorMAG407ForbiddentMethod = 12,	// Any method other than  "CONNECT" request will be rejected by MAG.
	AWProxyErrorMAG407DataUnavailable = 13,		// If no data are available for specific UDID and Bundle Id.
	AWProxyErrorMAG407InvalidThumbprint = 14,	// Invalid SHA-1 thumbprint for Udid and Bundle Id.
	AWProxyErrorMAG407NotCompliant = 15,		// Invalid compliance state for Udid and Bundle Id.
	AWProxyErrorMAG407NotManaged = 16,			// Unmanaged state for Udid and Bundle Id.
	AWProxyErrorMAG407CertInvalid = 17,			// The certficate is invalid.
    
    /* NTLM Auth attempt error*/
    AWProxyErrorMaximumAuthenticationAttempts = 100, // Maximum authentication attempts reached in NTLM prompt.
    
    AWProxyError = 1000, /* Generic Proxy Error */
    AWProxyError407 = 1001,
	
	/* Connection errors */
	AWProxyErrorConnectionClosedPrematurely = 1100,
    AWProxyErrorFailedToWriteToSocket = 1101,
	AWProxyErrorFailedToCreateStream = 1102,
    AWProxyErrorOutputStreamDoesNotExist = 1103,
    AWProxyErrorFailedToCreateResponseFromStream = 1104,
    AWProxyErrorFailedToCreateNTLMType1Message = 1105,
    AWProxyErrorFailedToCreateNTLMInfo = 1106,
    AWproxyErrorFailedToCreateNTLMType3Message = 1107,
    AWProxyErrorUnknownURLScheme = 1108,
    
	/* SSL Errors */
    AWProxySSLCertificateValidationError = 2000,
	
	/* Configuration Errors */
    AWProxyErrorAutoConfigURLMissing = 4000,
    AWProxyErrorFailedToGetPACScript = 4001,
    AWProxyErrorInvalidDataFromPACURL = 4002,
    AWProxyErrorProxyIsNotConfigured = 4003,
    AWProxyErrorFailedToRegisterProtocol = 4004,
	
    
	/* F5 Proxy Errors */
	AWPRoxyErrorF5Error = 5000,
    AWProxyErrorF5DNSResolutionFailed = 5001,
    AWProxyErrorF5FailedToConnect = 5002,
    AWProxyErrorF5UsernameAuthFailed = 5003,
    AWProxyErrorF5FailedToSetClientIdentity = 5004,
    AWProxyErrorF5FailedToCheckSessionLifetime = 5005,
    AWProxyErrorF5FailedToSetSession = 5006,
    
	/* MAG Proxy errors */
    AWProxyErrorFailedToSignRequest = 6000,
	AWProxyErrorFailedToFetchMAGCertWithHMAC = 6001,
	AWProxyErrorCertRequestInProgress = 6002,
    AWProxyErrorCertNotPresent = 6003,
	AWProxyErrorFailedToFetchMAGCertMissingHMAC = 6004,
	AWProxyErrorFailedToFetchMAGCertInvalidHMAC = 6005,
	AWProxyErrorFailedToStoreMAGCert = 6006,
    
    /* FUJI Proxy Errors */
    AWProxyErrorFujiProxyNotStart = 7000,
    AWProxyErrorFujiProxyNotConfigured = 7001,
};

#ifdef __cplusplus
};
#endif

#endif
