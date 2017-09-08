/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
#import <Foundation/Foundation.h>
#import "AWProxy.h"

@interface AWProxy (Private)
{
    
}

/*
 Returns a user-pass for use in the Proxy-Authorization header field.
 */
- (NSString *)getUserPassProxyCredential;


/*
 Returns a properly formatted user-pass for use in an authorization header field.
 https://www.ietf.org/rfc/rfc2617.txt
 */
- (NSString *)userPassFromUser:(NSString *)user andPass:(NSString *)pass;


- (NSMutableArray *) getSSLPinningCertificates;
- (void) addSslPinningCertificates:(NSData *) sslPinningCertificate;

- (NSData *) getDeviceServiceRootCertificate;

/*
 Reset standard proxy settings like host,http port and https port from Proxy auto-config (PAC) file for a requested URL.
 return BOOL indicating if proxy should be used. !!! Note this is a hack for BUG: 97546
 */
- (BOOL)setProxySettingsForURL:(NSURL *)url;

/*
 Fetch standard proxy auto configuration script (PAC file) contents from a URL.
 */
- (BOOL)fetchPACFile:(NSError **)error;

+ (BOOL)shouldRefetchMAGCert:(NSInteger)awErrorCode;

-(NSString *)writeAppTunnelDomainsToPacFileForLocalProxy:(NSString *)localProxy domains:(NSArray *)domains error:(NSError **)error;



-(BOOL) checkShouldProxyHandleRequest:(const char *)requestURL withHost:(const char *)requestHost;
@end
