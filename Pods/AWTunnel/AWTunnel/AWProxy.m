//  AWProxy.m
//
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//


#import <AWTunnel/AWTunnel-Swift.h>

#import "AWbase64.h"
#import "AWProxy+Private.h"
#import "AWProxyErrors.h"
#import "AWProxy_F5.h"
#import "AWTunnelLogger.h"

#import "AWF5ProxyController.h"
#import "FNProxySupportPriv.h"

#import "AWForwarderService.h"
#import "AWProxyHandler.h"


@import AWServices;
@import AWCrypto;
@import AWLocalization;
@import AWLog;


@interface AWProxy () <AWAppSnapshotReporter>
{
	BOOL isRequestingCert;
}
@property (nonatomic, copy) NSString * userPassProxyCredential;
@property (nonatomic, copy) NSString * proxyAutoConfigScript;
@property (nonatomic, assign)NSInteger localProxyPort;
@property (nonatomic, strong) NSMutableArray * sslPinningCertificates;
@property (nonatomic, strong) NSData * deviceServicesRootInMemory;

@end

int should_proxy_handle_request (const char * requestURL, const char * host)
{
    return [[AWProxy sharedInstance] checkShouldProxyHandleRequest:requestURL withHost:host];
}


@implementation AWProxy

#pragma mark - Lifecycle
- (id)init
{
    if ((self = [super init]))
    {
        self.requiresAuth = NO;
        _shouldSignRequests = YES;
        _usePublicMAGCert = NO;
        _isEnabled = NO;
		isRequestingCert = NO;
        _delegate = nil;
    }
    return self;
}

- (void)dealloc
{
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
#endif
    _delegate = nil;
}

+ (AWProxy*)sharedInstance
{
	static dispatch_once_t onceToken;
	static AWProxy *MAGProxy = nil;
	
	dispatch_once(&onceToken, ^{
		MAGProxy = [[self alloc] init];
        [[AWAppSnapshotController sharedInstance] register:MAGProxy];
	});
	
	return MAGProxy;
}

#pragma mark - Configuration
- (void)configureWithHost:(NSString *)host
          httpPort:(NSInteger)http
         httpsPort:(NSInteger)https
        serverType:(AWProxyServerType)type
{
    _host = [host copy];
    _httpPort = http;
    _httpsPort = https;
    [self setType:type];
    AWLogInfo(@"New proxy settings.");
    AWLogDebug(@"Host: %@ http: %ld https: %ld type: %d", self.host, (long)self.httpPort,
               (long)self.httpsPort, self.type);
}

#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
- (void)configureF5ProxyWithHost:(NSString *)proxyHost
                            port:(NSInteger)proxyPort
                        authType:(AWF5AuthenticationMode)authType
						userName:(NSString *)name
						password:(NSString *)pwd
                        certData:(NSData *)certData
                      passPhrase:(NSString *)pphrase
{
    _host = [proxyHost copy];
    _httpsPort = proxyPort;
	self.password = pwd;
	self.username = name;
    _f5ProxyAuthType = authType;
    _p12CertDataForF5 = [certData copy];
    _passPhraseForF5Cert= [pphrase copy];
    [self setType:AWproxyServerTypeF5];
}
#endif

- (BOOL)isConfigured
{
    BOOL retStatus = YES;
    
    if (![self.host length])
    {
        retStatus = NO;
    } else if (self.httpPort < 0 && self.httpsPort < 0)
    {
        retStatus = NO;
    }
    return retStatus;
}

- (BOOL)isF5ProxyAuthTypeUsernamePassword
{
    BOOL isTypeUsernamePassword = NO;

#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
    isTypeUsernamePassword = [self f5ProxyAuthType] == AWF5AuthenticationModeUsernameAndPassword;
#endif

    return isTypeUsernamePassword;
}

- (void)setupUsernamePasswordForF5WithSSOIdentity
{
    if (![self.host length] ||  (self.httpsPort < 0))
    {
        return;
    }

    if([self isF5ProxyAuthTypeUsernamePassword] &&
       (![self.username length]  || ![self.password length]))
    {
#if 0
        AWProxyPayload *proxyPayload = [[AWCommandManager sharedManager] sdkProfile].proxyPayload;
        if([proxyPayload.f5UserAccountType integerValue] == 1)
        {
            // f5UserAccountType = 1 means SSO identity, f5UserAccountType = 0 means service account.
            AWEnrollmentAccount *account = [[AWController clientInstance] account];
            if(account && account.username.length && account.password.length)
            {
                [self setUsername:account.username];
                [self setPassword:account.password];
            }
            else
            {
                AWLogInfo(@"Couldn't setup username and password");
            }
        }
#else
        AWLogError(@"Username and password are required to setup F5 proxy!");
#endif
    }
}

#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
- (BOOL)isF5Configured
{
    BOOL retStatus = YES;
    if (![self.host length] ||  (self.httpsPort < 0))
    {
        retStatus = NO;
        return retStatus;
    }
    switch ([self f5ProxyAuthType]) {
            
        case AWF5AuthenticationModeUsernameAndPassword:
            if ( (![self.username length])  || (![self.password length]) ){

                retStatus = NO;

            }
            break;
            
        case AWF5AuthenticationModeCertificate:
            if ((self.p12CertDataForF5 == nil) || (![self.passPhraseForF5Cert length]) ){
                retStatus = NO;
            }
            break;
            
        case AWF5AuthenticationModeUsernamePasswordAndCertificate:
            if ( (![self.username length])  || (![self.password length]) ){
                retStatus = NO;
            }
            else if ((self.p12CertDataForF5 == nil) || (![self.passPhraseForF5Cert length]) ){
                retStatus = NO;
            }
            break;
            
        default:
            retStatus = NO;
            break;
    }

    return retStatus;
}
#endif

#pragma mark - Starting / Stopping

- (BOOL)start:(NSError**)error
{
    if (self.isEnabled)
    {
        return YES;
    }
    
    BOOL canStart = NO;
    NSError *outErr = nil;
    
    if (AWproxyServerTypeMAG == self.type)
    {
        if (![self checkMAGCert]) {
            outErr = AWErrorMacro(AWProxyErrorDomain, AWProxyErrorCertNotPresent, @"The MAG certifcate is not present.",
								  @"Call fetchMAGCertificate: and restart the proxy.",nil);
            canStart = NO;
            
        } else if (![self isConfigured]) {
            outErr = AWErrorMacro(AWProxyErrorDomain,
                                  AWProxyErrorProxyIsNotConfigured,
                                  AWSDKLocalizedString(@"AWProxy is not configured correctly.",nil),
                                  AWSDKLocalizedString(@"Make sure required properties are set.",nil),
                                  nil);
            canStart = NO;
        } else {
 
            AWLogInfo(@"Starting MAG Proxy");
            canStart = YES;
            outErr = nil;
        }

    }
    else if (AWProxyServerTypeStandard == self.type)
    {
        if(self.autoConfigURL)
        {
            AWLogInfo(@"Using Proxy Auto Configuration");
            outErr = nil;
            canStart = [self fetchPACFile:&outErr];
        } else
        {
            if ([self isConfigured])
            {
                AWLogInfo(@"Starting Standard Proxy");
                canStart = YES;
                outErr = nil;
            } else
            {
                canStart = NO;
                outErr = AWErrorMacro(AWProxyErrorDomain,
                                      AWProxyErrorProxyIsNotConfigured,
                                      AWSDKLocalizedString(@"AWProxy is not configured correctly.",nil),
                                      AWSDKLocalizedString(@"Make sure required properties are set.",nil),
                                      nil);
            }
        }
    }
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
    else if (AWproxyServerTypeF5 == self.type)
    {
        [self setupUsernamePasswordForF5WithSSOIdentity];

        if ([self isF5Configured])
        {
            AWLogInfo(@"Starting F5 Proxy");
            canStart = [[AWF5ProxyController sharedInstance] startF5ProxyWithError:&outErr];
        } else
        {
            outErr = AWErrorMacro(AWProxyErrorDomain,
                                  AWProxyErrorProxyIsNotConfigured,
                                  AWSDKLocalizedString(@"AWProxy is not configured correctly.",nil),
                                  AWSDKLocalizedString(@"Make sure required properties are set.",nil),
                                  nil);
            canStart = NO;
        }
        
    }
#endif
    else
    {
        outErr = AWErrorMacro(AWProxyErrorDomain,
                              AWProxyErrorProxyIsNotConfigured,
                              AWSDKLocalizedString(@"AWProxy is not configured correctly.",nil),
                              AWSDKLocalizedString(@"Set self.type to a valid value.",nil),
                              AWSDKLocalizedString(@"ProxyServerType is set to Unknown.",nil));
        canStart = NO;
    }
    
    if (canStart)
    {
        if(!_isEnabled) {
            _isEnabled = [[AWForwarderService sharedInstance] startForwarderService];
        }
    } else
    {
        _isEnabled = NO;
    }
    
    if (error)
    {
        *error = outErr;
    }

    if (_isEnabled)
    {
        set_proxy_handler_function(&should_proxy_handle_request);
    }
    
    return self.isEnabled;
}



- (void)stop
{
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
    if (AWproxyServerTypeF5 == self.type){
        
        [[AWF5ProxyController sharedInstance] stopF5proxy];
    }
#endif
    if(_isEnabled) {
        [[AWForwarderService sharedInstance] stopProxyWithCompletion:nil];
    }
    
    self.sslPinningCertificates = nil;
    _isEnabled = NO;
    set_proxy_handler_function(NULL);
}

/*
 This is a wrapper for the private AWProxyCertService.
 Checks to make sure we're configured to use MAG and that we have an HMAC before fetching a certifecate using 
 AWProxyCertSerivce. 
 Param: callback - block that passess two parameters: a bool to indicate success, a NSError to indicate the error...
 */
- (void)fetchMAGCertificate:(certificateFetchCallback)callback
{
    if (self.type != AWproxyServerTypeMAG) {
        callback(NO,AWErrorMacro(AWProxyErrorDomain,
                                 AWProxyErrorProxyIsNotConfigured,
                                 @"Only MAG proxy requires a certificate.",
                                 nil,
                                 nil));
    }
    
    [self.proxyCertService fetchAndStoreCertWithCompletion:^(BOOL success, NSError *error) {
            callback(success, error);
    }];
}

#pragma mark - Accessors

- (void)setType:(AWProxyServerType)type
{
    _type = type;
    if (AWproxyServerTypeMAG == type)
    {
        self.shouldSignRequests = YES;
    } else
    {
        self.shouldSignRequests = NO;
    }
}

- (void)setDelegate:(id<AWProxyDelegate>)delegate
{
    if (_delegate)
    {
        AWLogInfo(@"Setting a new delegate on the AWProxy singleton.");
    }
    _delegate = delegate;
}

- (BOOL)checkMAGCert
{
    NSData *certData = [self.proxyCertService signingCertificate];
    
    if (certData) {
        return YES;
    } else {
        return NO;
    }
}

-(NSString *)description;
{
	NSString *retValue = [NSString stringWithFormat:@"Host: %@\nHTTP: %ld\nHTTPS: %ld\nType: %d\nDelegate: %@", self.host,
						  (long)self.httpPort,(long)self.httpsPort,self.type,self.delegate];
	return retValue;
}

#pragma mark - App Snapshot Methods
- (NSString *)snapshotReportTitle
{
    return @"AWProxy Report";
}

- (NSString *)snapshotReport
{
    AWProxy *proxy = [AWProxy sharedInstance];
    
    NSData *certThumb = [[self.proxyCertService signingCertificate] aw_sha1];
    
    NSMutableString *string = [[NSMutableString alloc] init];
    [string appendFormat:@"      Proxy Type: %@\n", [self stringForProxyType:[proxy type] ]];
    [string appendFormat:@"   Proxy Enabled: %@\n", [proxy isEnabled]?@"YES":@"NO"];
    [string appendFormat:@"      Proxy Host: %@\n", [proxy host]];
    [string appendFormat:@"     Proxy Ports: %ld / %ld\n", (long)[proxy httpPort], (long)[proxy httpsPort]];
    [string appendFormat:@"  Proxy Use Auth: %@\n", [proxy requiresAuth]?@"YES":@"NO"];
    [string appendFormat:@" Proxy User/Pass: %@\n", [proxy username]];
    [string appendFormat:@"Proxy Cert Thumb: %@\n", [certThumb description]];
    
    return string;
}

- (NSString *)stringForProxyType:(AWProxyServerType)type
{
    NSString *retVal = @"";
    switch (type) {
        case AWProxyServerTypeStandard:
            retVal = @"Standard Proxy";
            break;
        case AWproxyServerTypeMAG:
            retVal = @"MAG Proxy";
            break;
        case AWproxyServerTypeF5:
            retVal = @"F5 Proxy";
            break;
        case AWProxyServerTypeUnknown:
        default:
            retVal = @"Unknown Proxy Type";
            break;
    }
    return retVal;
}

@end

#pragma mark -

@implementation AWProxy (Private)

- (NSString *)getUserPassProxyCredential
{
    if (_userPassProxyCredential)
    {
        return _userPassProxyCredential;
    }
    else
    {
        self.userPassProxyCredential = [self userPassFromUser:self.username andPass:self.password];
        return self.userPassProxyCredential;
    }
}


/*
 Returns a properly formatted and base64 encoded user-pass for use in an authorization header field.
 https://www.ietf.org/rfc/rfc2617.txt Section 2
 
 e.g Aladdin:open sesame  =>  QWxhZGRpbjpvcGVuIHNlc2FtZQ==
 */
- (NSString *)userPassFromUser:(NSString *)user andPass:(NSString *)pass
{
    if (![user length] || ![pass length])
    {
        return @"";
    } else
    {
        // Set Proxy-Authorization Header.
        const char *u, *p;
        u = [user cStringUsingEncoding:NSUTF8StringEncoding];
        p = [pass cStringUsingEncoding:NSUTF8StringEncoding];
        
        // length of user + length of password + ':' + \0
        size_t len = strnlen(u,2048) + strnlen(p,2048) + 2;
        char * up = malloc(len);
        if (up == NULL) {
            return @"";
        }
        strlcpy(up, u, len);
        strlcat(up, ":", len);
        strlcat(up, p, len);
        
        size_t out_size;
        char * base64_up = aw_base64_encode((unsigned char *)up, len - 1, &out_size);
        free(up);
        
        return [[NSString alloc] initWithCString:base64_up
                                         encoding:NSUTF8StringEncoding];
    }
}

/*
 fetches the pac script located at the url specified by self.autoConfigURL
 stores the script in self.proxyAutoConfigScript
 returns the status of the operation
 
 return status and error are mutually exclusive
 */
- (BOOL)fetchPACFile:(NSError **)error;
{
    AWLogVerbose(@"Fetching PAC file from [%@]",self.autoConfigURL);
    if(!self.autoConfigURL)
    {
        [self setProxyAutoConfigScript:nil];
        NSString *desc = AWSDKLocalizedString(@"FailedToGetPACscript", nil);
        NSString *recv = AWSDKLocalizedString(@"SetAutoConfigURLProperty", nil);
        NSString *reas = AWSDKLocalizedString(@"AutoConfigURLPropertyIsNotSet", nil);

        AWLogError(@"%@",reas);
        NSError *err = AWErrorMacro(AWProxyErrorDomain, AWProxyErrorAutoConfigURLMissing,
                                    desc, recv, reas);
        if (error)
            *error = err;
        return NO;
    }
    NSData *data = nil;
    data = [NSData dataWithContentsOfURL:self.autoConfigURL];
    BOOL status;
    NSError *outErr;
    if([data length])
    {
        NSString *autoConfigScript = [[NSString alloc] initWithData:data
                                                           encoding:NSUTF8StringEncoding];
        if ([autoConfigScript length])
        {
            self.proxyAutoConfigScript = autoConfigScript;
            status = YES;
            outErr = nil;
        } else
        {
            [self setProxyAutoConfigScript:nil];
            NSString *desc = AWSDKLocalizedString(@"FailedToGetPACscript", nil);
            NSString *recv = AWSDKLocalizedString(@"MakeSureForValidScriptLocatedAtAutoConfigURL", nil);
            NSString *reas = AWSDKLocalizedString(@"FailedToDecodeAutoConfigUrlRetrievedData", nil);
            AWLogError(@"%@",reas);
            outErr = AWErrorMacro(AWProxyErrorDomain, AWProxyErrorInvalidDataFromPACURL,
                                  desc, recv, reas);
            status = NO;
        }
        
    }
    else
    {
        [self setProxyAutoConfigScript:nil];
        NSString *desc = AWSDKLocalizedString(@"FailedToGetPACscript", nil);
        NSString *recv = AWSDKLocalizedString(@"MakeSurePACURLisValid", nil);
        NSString *reas = AWSDKLocalizedString(@"FailedToRetrievedAutoConfigUrlData", nil);
        AWLogWarning(@"%@",reas);
        outErr = AWErrorMacro(AWProxyErrorDomain, AWProxyErrorFailedToGetPACScript,
                              desc, recv, reas);
        status = NO;
    }
    
    if (error)
    {
        *error = outErr;
    }
    
    return status;
    
} /* fetchPACFile: */

/*
 This method uses CFNetworkCopyProxiesForAutoConfigurationScript to determine host and port information for the provided
 url. This method sets self.host and self.httpPort and self.httpsPort automatically.
 
 This method won't do anyting if self.proxyAutoConfigScript == nil Be sure to either manuall set proxyAutoConfigScript or
 set self.autoConfigURL and call fetchPACFile:
 
 */
- (BOOL)setProxySettingsForURL:(NSURL *)url
{
	BOOL retStatus;
	if (self.proxyAutoConfigScript)
	{
		// From: http://developer.apple.com/samplecode/CFProxySupportTool/listing1.html
		// Work around <rdar://problem/5530166>. This dummy call to
		// CFNetworkCopyProxiesForURL initialise some state within CFNetwork
		// that is required by CFNetworkCopyProxiesForAutoConfigurationScript.
		CFRelease(CFNetworkCopyProxiesForURL((__bridge CFURLRef)url, (__bridge CFDictionaryRef)(@{})));
		
		AWLogInfo(@"Getting proxy settings from PAC file.");
		AWLogVerbose(@"Getting proxies for URL: %@", url);
		
		CFErrorRef err = NULL;
		NSArray *proxies = (__bridge_transfer id)(CFNetworkCopyProxiesForAutoConfigurationScript\
											  ((__bridge CFStringRef)self.proxyAutoConfigScript,
											   (__bridge CFURLRef)url, &err));
		
		if (err)
		{
			AWLogError(@"Failed to get proxies from auto config script due to error: %@",
					   (__bridge NSError*)err);
			retStatus = NO;
		} else
		{
			if ([proxies count])
			{
				NSDictionary *settings = [proxies objectAtIndex:0];
				
				BOOL isProxyTypeNone = [[settings objectForKey:(NSString *)kCFProxyTypeKey] isEqualToString:(NSString *)kCFProxyTypeNone];
				BOOL hasPort = ([settings objectForKey:(NSString *)kCFProxyPortNumberKey] != nil);
				NSString *host = [settings objectForKey:(NSString *)kCFProxyHostNameKey];
				
				if (isProxyTypeNone || !hasPort || !host)
				{
					AWLogInfo(@"Not using proxy. Connecting directly.");
					retStatus = NO;
				} else
				{
					[self configureWithHost:host
								   httpPort:[[settings objectForKey:(NSString *)kCFProxyPortNumberKey] intValue]
								  httpsPort:[[settings objectForKey:(NSString *)kCFProxyPortNumberKey] intValue]
								 serverType:AWProxyServerTypeStandard];
					
					retStatus = YES;
				}
			} else
			{
				AWLogWarning(@"No proxies found for host: %@", [url host]);
				retStatus = NO;
			}
		}
		
	} else
	{
		AWLogVerbose(@"Missing PAC script. Be sure to use fetchPACFile:");
		retStatus = NO;
	}
	
	return retStatus;
}

-(NSString *)writeAppTunnelDomainsToPacFileForLocalProxy:(NSString *)localProxy domains:(NSArray *)domains error:(NSError **)error
{
    
    NSMutableString *pacFileString = [[NSMutableString alloc] initWithString:@"function FindProxyForURL(url, host){"];
    
    [pacFileString appendFormat:@"var proxy_yes=\"PROXY %@\";",localProxy];
    [pacFileString appendString:@"var proxy_no=\"DIRECT\";"];
    
    if (domains.count > 0)
    {
        [pacFileString appendString:@"var isUrlInDomain=("];
    }
    
    NSInteger index = 1;
    for (NSString *domain in domains) {
        if(index != domains.count)
            [pacFileString appendFormat:@"shExpMatch(url, \"%@\") || ", domain];
        else
            [pacFileString appendFormat:@"shExpMatch(url, \"%@\"));", domain];
            
        index++;
    }
    
    // Add exception for console
    NSString *consoleHost = [[[AWServer sharedInstance] deviceServicesURL] host];
    [pacFileString appendFormat:@"if (shExpMatch(url, \"*%@*\")) { return proxy_no; } ", consoleHost];
    
    
    if (domains.count == 0) {
        [pacFileString appendString:@"return proxy_yes;}"];
    } else {
        [pacFileString appendString:@"if (isUrlInDomain) { return proxy_yes; } "];
        [pacFileString appendString:@"return proxy_no;}"];
    }
    
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSString *filePath = [documentsDirectory
                          stringByAppendingPathComponent:@"local.pac"];
    // Write to the file
    [pacFileString writeToFile:filePath atomically:YES
                    encoding:NSUTF8StringEncoding error:error];
    
    if(!*error) {
        return filePath;
    }
    return nil;
}

- (NSMutableArray *) getSSLPinningCertificates
{
    return self.sslPinningCertificates;
}

- (void) addSslPinningCertificates:(NSData *) sslPinningCertificate
{
    if (!self.sslPinningCertificates) {
        self.sslPinningCertificates = [[NSMutableArray alloc] init];
    }
    
    [self.sslPinningCertificates addObject:CFBridgingRelease(SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)sslPinningCertificate))];
}

- (NSData *) getDeviceServiceRootCertificate
{
    /* Lets put the deviceServiceRootCertificate in memory so we don't have to use storage helper for every request. */
    
    if (!self.deviceServicesRootInMemory)
    {
        self.deviceServicesRootInMemory = [AWProxyCertService deviceRootCertificate];

    }
    
    return self.deviceServicesRootInMemory;
}


-(BOOL) checkShouldProxyHandleRequest:(const char *)requestURL withHost:(const char *)requestHost
{
    NSString *requestHostOrURL = nil;
    
    if (NULL != requestURL) {
        requestHostOrURL = [NSString stringWithUTF8String:requestURL];
    } else if (NULL != requestHost) {
        requestHostOrURL = [NSString stringWithUTF8String:requestHost];
    }
    
    if(requestHostOrURL &&
       self.delegate &&
       [self.delegate respondsToSelector:@selector(proxyShouldHandleRequest:)])
    {
        NSURL *url = [NSURL URLWithString:requestHostOrURL];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        return [self.delegate proxyShouldHandleRequest:request];
    }
    return NO;
}

+(BOOL)shouldRefetchMAGCert:(NSInteger)awErrorCode{
    return (AWProxyErrorMAG407UntrustedIssuer == awErrorCode ||
            AWProxyErrorMAG407DataUnavailable == awErrorCode ||
            AWProxyErrorMAG407InvalidThumbprint == awErrorCode ||
            AWProxyErrorMAG407CertInvalid == awErrorCode ||
            AWProxyErrorMAG407EmptyCertChain == awErrorCode);
}

@end
