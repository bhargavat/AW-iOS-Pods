//
//  AWProxyHandler.m
//  AirWatch
//
//  Created by Airwatch on 12/17/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//


#import <AWTunnel/AWTunnel-Swift.h>
#import <Fuji/NSData+Base64.h>

#import "AWForwarderService.h"
#import "AWRequestSigner.h"
#import "AWProxyHandler.h"
#import "AWProxy+Private.h"
#import "AWProxy_F5.h"
#import "AWProxyErrors.h"
#import "AWTunnelLogger.h"

#import "ProxyAuthTokenHelper.h"

#include <sys/socket.h>
#import <netdb.h>

@import AWServices;
@import AWHelpers;

#define kWildcard                           @"*"
#define kSchemeRegex                        @"((https?|ftps?)://)?"
#define kDomainRegex                        @"([\\.\\-0-9a-zA-Z])*"
#define kTrailingDomainRegex                @"([:\\.\\-0-9a-zA-Z])*"
#define kMAGReachabilityTimeout             5

NSString *const magReachabilityTestURL = @"https://404.air-watch.com";



@interface AWProxyHandler() <AWProxyDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate> {
    BOOL _isSettingUpProxy;
    BOOL fetchMAGCertificate;

}

- (void)returnWithSuccess:(BOOL) success andError:(NSError*)error;

@property (nonatomic, copy) ProxySetupCompletion completionBlock;
@property (nonatomic, assign) BOOL didStartLocalProxy;
@property (nonatomic, strong) NSError *startLocalProxyError;

@end

@implementation AWProxyHandler

+ (AWProxyHandler *)sharedInstance
{
    static dispatch_once_t onceToken;
    static AWProxyHandler *awProxyHandler = nil;
    
    dispatch_once(&onceToken, ^{
        
        awProxyHandler = [[AWProxyHandler alloc] init];
    });
    
    return awProxyHandler;
}

NSURL * magTestURL() {
    
    NSURL *defaultURL = [NSURL URLWithString:magReachabilityTestURL];
    //@import SDKDefaultSettings

    BOOL isHTTPEnabled = [[SDKDefaultSettings sharedSettings] isHTTPMAGTestURLEnabled];
    if (isHTTPEnabled) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:defaultURL resolvingAgainstBaseURL:YES];
        components.scheme = @"http";
        NSURL *httpMAGTestURL = [components URL];
        return httpMAGTestURL;
    }
    
    return defaultURL;
}

- (void)setupProxy:(id<AWProxyPayload>)proxyPayload withCompletion:(ProxySetupCompletion)callback;
{

#ifdef ENABLE_PROXY
    if (_isSettingUpProxy)
    {
        return;
    }
    if (proxyPayload == nil || [proxyPayload conformsToProtocol:@protocol(AWProxyPayload)] == NO)
    {
        AWLogWarning(@"Payload empty");
        NSError *error = [NSError errorWithDomain:AWSDKErrorDomain code:AWProxySetupErrorPayloadEmpty userInfo:nil];
        if (callback)
            callback(NO,error);
        return;
    }
    self.completionBlock = callback;
    _isSettingUpProxy = YES;
    [AWProxy sharedInstance].appTunnelDomains = [proxyPayload appTunnelDomains];
    [[AWProxy sharedInstance] setDelegate:self];
    
    if ([proxyPayload redirectTraffic]) {
        AWLogInfo(@"Proxy Payload found and traffic should be redirected.");
        
        NSString *host = [proxyPayload hostName];
        NSNumber *httpPort = [NSNumber numberWithInteger:[proxyPayload httpPort]];
        NSNumber *httpsPort = [NSNumber numberWithInteger:[proxyPayload httpsPort]];
        
        if ([proxyPayload proxyType] == AWProxyTypeMag) {
            AWLogInfo(@"MAG proxy type");
            AWLogInfo(@"Configuring mag with %@, %@, %@",host,httpPort,httpsPort);
            AWLogInfo(@"Mag already has %@, %ld, %ld",
                      [[AWProxy sharedInstance] host],
                      (long)[[AWProxy sharedInstance] httpPort],
                      (long)[[AWProxy sharedInstance] httpsPort]);
            
            if (host && httpPort && httpsPort) {
                AWLogInfo(@"********** Configuring MAG");
                
                if ([[AWProxy sharedInstance] isEnabled])
                {
                    AWLogVerbose(@"Proxy Enabled, turning off for configuration");
                    [[AWProxy sharedInstance] stop];
                }
                
                BOOL rsaAdaptiveAuthEnabled = [proxyPayload magRSAAdaptiveAuthEnabled];
                [[AWProxy sharedInstance] setMagRSAAdaptiveAuthEnabled:rsaAdaptiveAuthEnabled];
            
#if !TARGET_IPHONE_SIMULATOR
                /* 
                 * Update the rsa string incase it was changed.
                 * This is to handle the case where the MAG settings change
                 */
                if([self.delegate respondsToSelector:@selector(deviceInfoLevelForRSAAA)]) {
                   AWRSAAADeviceInfoLevel deviceInfoLevel =  [self.delegate deviceInfoLevelForRSAAA];
                    [[AWRequestSigner sharedInstance] setDataCollectionLevel:deviceInfoLevel];
                }else {
                    [[AWRequestSigner sharedInstance] updateRSAJSONString];
                }
                
#endif
                
                if ([host length] <= 0){
                    AWLogWarning(@"Proxy Hostname empty. Not configuring proxy");
                    NSError *returnError = [NSError errorWithDomain:AWSDKErrorDomain code:AWProxySetupErrorHostNameEmpty userInfo:nil];
                    [self returnWithSuccess:NO andError:returnError];
                    return;
                }
                
                [[AWProxy sharedInstance] configureWithHost:host
                                                   httpPort:[httpPort integerValue]
                                                  httpsPort:[httpsPort integerValue]
                                                 serverType:AWproxyServerTypeMAG];
                
                [[AWProxy sharedInstance] setUsePublicMAGCert:proxyPayload.publicSSL];
                
                /* Set MAG SSL pinning certs */
                if ([proxyPayload magSSLCertificates])
                {
                    for (NSString * cert in [proxyPayload magSSLCertificates]) {
                        if (cert && cert.length)
                        {
                            [[AWProxy sharedInstance] addSslPinningCertificates: [NSData AW_base64DecodedData:cert]];
                        }
                    }
                }
                
                NSData *pfxCert = [AWProxyCertService signingCertificate];
                if (!pfxCert.length) {
                    AWLogInfo(@"MAG cert not present will fetch");
                    [self fetchMagCert];
                } else {
                    
                    self.didStartLocalProxy = [self startProxyWithError:self.startLocalProxyError];
                    
                    if(!self.startLocalProxyError) {
                        //Fuji started, lets check to make sure mag cert is proper sending a test request.
                        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:magReachabilityTestURL]
                                                                               cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                                           timeoutInterval:kMAGReachabilityTimeout];
                        
                        NSString *token = [NSString stringWithUTF8String:getProxyAuthToken()];
                        [request setValue:token forHTTPHeaderField:@"Proxy-Authorization"];
                        
                        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
                        if([[UIDevice currentDevice].systemVersion intValue] > 8){
                            NSString * proxyHost = @"localhost";
                            NSNumber* proxyPort = [NSNumber numberWithInteger:[[AWForwarderService sharedInstance] localProxyPort] ];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                            NSDictionary *proxyDict = @{
                                                        @"HTTPEnable"  : [NSNumber numberWithInt:1],
                                                        (NSString *)kCFStreamPropertyHTTPProxyHost  : proxyHost,
                                                        (NSString *)kCFStreamPropertyHTTPProxyPort  : proxyPort,
                                                        
                                                        @"HTTPSEnable" : [NSNumber numberWithInt:1],
                                                        (NSString *)kCFStreamPropertyHTTPSProxyHost : proxyHost,
                                                        (NSString *)kCFStreamPropertyHTTPSProxyPort : proxyPort,
                                                        };
#warning "FIXME: 💡Using deprecated stuff... Needed A fix. 🔧"
#pragma GCC diagnostic pop
                            
                            defaultConfigObject.connectionProxyDictionary = proxyDict;
                        }
                        
                        NSURLSession* defaultSession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:self delegateQueue:[NSOperationQueue currentQueue]];
                        
                        NSURLSessionDataTask* reachabilityTask = [defaultSession dataTaskWithRequest:request];
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reFetchMAGCert:) name:AWRefetchMAGCertificate object:nil];
                        
                        
                        [reachabilityTask resume];
                        
                        
                    } else {
                        [self returnWithSuccess:self.didStartLocalProxy andError:self.startLocalProxyError];
                    }
                }
                
            }
            
        } else if ([proxyPayload proxyType] == AWProxyTypeF5) {
            AWLogInfo(@"F5 proxy type");
#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
            NSNumber *f5Port = [NSNumber numberWithInteger:[proxyPayload f5Port]];
            
            AWF5AuthenticationMode f5Auth = [proxyPayload f5AuthenticationMode];
            NSData *cert = nil;
            if ([self.delegate respondsToSelector:@selector(certificateData)])
            {
                cert = [self.delegate certificateData];
            } else
            {
                AWLogWarning(@"Cannot get certificate data: ");
            }
            NSString *certPass = nil;
            if ([[self delegate] respondsToSelector:@selector(certificatePassword)])
            {
                certPass = [self.delegate certificatePassword];
            }
            else
            {
                AWLogWarning(@"Cannot get certificate data: ");
            }
            
            if (cert && certPass)
            {
                cert = [[[AWProxy sharedInstance] proxyCertService] convertP12CertificateToFIPS:cert
                                                                                       password:[certPass dataUsingEncoding:NSUTF8StringEncoding]];

            }
            
            NSString *uname = proxyPayload.f5UserAccountName;
            NSString *pass = proxyPayload.f5UserAccountPassword;
            NSString *f5Host = proxyPayload.f5Host;
            
            if ([[AWProxy sharedInstance] isEnabled]) {
                AWLogVerbose(@"Proxy Enabled, turning off for configuration");
                [[AWProxy sharedInstance] stop];
            }
            
            AWLogInfo(@"All required fields are present. Configuring F5");
            [[AWProxy sharedInstance] configureF5ProxyWithHost:f5Host
                                                          port:[f5Port integerValue]
                                                      authType:f5Auth
                                                      userName:uname
                                                      password:pass
                                                      certData:cert
                                                    passPhrase:certPass];
            NSError *error = nil;
            BOOL started = [[AWProxy sharedInstance] start:&error];
            if (started) {
                AWLogVerbose(@"F5 Proxy turned ON");
                [self returnWithSuccess:YES andError:nil];
            } else {
                AWLogVerbose(@"F5 Proxy encountered error while starting: %@", error);
                [self returnWithSuccess:NO andError:error];
            }
#pragma clang diagnostic pop
            
#else
            AWLogError(@"Trying to configure F5 while running a build compiled witout F5");
            AWLogVerbose(@"Proxy was not configured");
            // => Proxy is disabled. No Error
            [[AWProxy sharedInstance] stop];
            [self returnWithSuccess:YES andError:nil];
#endif
            
        }else if ([proxyPayload proxyType] == AWProxyTypeStandard){
            {
                BOOL requiresAuth = proxyPayload.standardProxyUseAuth;
                [[AWProxy sharedInstance] setRequiresAuth:proxyPayload.standardProxyUseAuth];
                if (requiresAuth)
                {
                    [[AWProxy sharedInstance] setUsername:proxyPayload.standardProxyUsername];
                    [[AWProxy sharedInstance] setPassword:proxyPayload.standardProxyPassword];
                }
                
                BOOL isAutoConfig = proxyPayload.standardProxyAutoConfig;
                if (isAutoConfig)
                {
                    NSURL *url = [NSURL URLWithString:proxyPayload.standardProxyAutoConfigURL];
                    [[AWProxy sharedInstance] setAutoConfigURL:url];
                } else {
                    [[AWProxy sharedInstance] setAutoConfigURL:nil];
                }
                
                NSString *host = proxyPayload.hostName;
                NSInteger httpPort = proxyPayload.httpPort;
                NSInteger httpsPort = proxyPayload.httpsPort;
                
                AWLogDebug(@"Configuring Standard Proxy settings: %@, %ld, %ld, %d",
                           host, (long)httpPort, (long)httpsPort, AWProxyServerTypeStandard);
                AWLogInfo(@"Configuring Standard Proxy settings for type %lu", (unsigned long)AWProxyServerTypeStandard);
                
                [[AWProxy sharedInstance] setHost:host];
                [[AWProxy sharedInstance] setHttpPort:httpPort];
                [[AWProxy sharedInstance] setHttpsPort:httpsPort];
                [[AWProxy sharedInstance] setType:AWProxyServerTypeStandard];
                
                NSError *error = nil;
                BOOL start = [[AWProxy sharedInstance] start:&error];
                if (start)
                    AWLogInfo(@"Standard Proxy Is ON");
                else
                    AWLogError(@"Failed to Enabled Standard Proxy - %@", error);
                
                [self returnWithSuccess:start andError:error];
            }
            
        }
        else {
            AWLogVerbose(@"Proxy type not MAG or F5 or Standard Proxy");
            [[AWProxy sharedInstance] stop];
            NSError *returnError = [NSError errorWithDomain:AWSDKErrorDomain code:AWProxySetupErrorTypeNotSupported userInfo:nil];
            [self returnWithSuccess:NO andError:returnError];
        }
    } else {
        AWLogVerbose(@"Proxy was not configured");
        // => Proxy is disabled. No Error
        [[AWProxy sharedInstance] stop];
        [self returnWithSuccess:YES andError:nil];
    }
#else
    if (callback) {
        callback(YES,nil);
    }
    return;
#endif
}

-(void) fetchMagCert
{
    AWLogInfo(@"Fetching MAG Cert");
    __unsafe_unretained AWProxyHandler * blkHandler = self;
    [[AWProxy sharedInstance] fetchMAGCertificate:^(BOOL success, NSError *error) {
        
        AWLogInfo(@"********** Got MAG Cert: %@",success?@"YES":@"NO");
        
        if (success && !error) {
            [blkHandler startProxyWithError:error];
        } else {
            AWLogError(@"Error fetching mag cert: %@",error);
        }
        
        [blkHandler returnWithSuccess:success andError:error];
    }];
}


-(BOOL) startProxyWithError:(NSError *) error
{
#ifdef ENABLE_PROXY
    BOOL started = [[AWProxy sharedInstance] start:&error];
    if (started) {
        AWLogInfo(@"********** MAG Started");
        
        AWLogInfo(@"MAG Proxy turned ON");
        AWLogVerbose(@"Forwarding to main app b/c its waiting on mag cert");
        
        
    } else {
        AWLogWarning(@"MAG Proxy encountered error while starting: %@", error);
    }
    return started;
#else 
    return YES;
#endif
}

- (void)returnWithSuccess:(BOOL)success andError:(NSError *)error
{
    _isSettingUpProxy = NO;
    if (!success || error != nil) {
        [AWProxy sharedInstance].appTunnelDomains = nil;
        [[AWProxy sharedInstance] stop];
        success = false;
    }
    
    if (self.completionBlock)
        self.completionBlock(success,error);
}

+ (BOOL)domain:(NSString *)domain matchesRequest:(NSURLRequest *)request
{
    
    if (!request.URL || request.URL.absoluteString.length == 0) {
        return NO;
    }
    
    
    if([domain characterAtIndex:[domain length]-1] == '/') {
        domain = [domain substringToIndex:[domain length]-1];
    }
    
    
    NSString *originalString;
    
    NSNumber *port = request.URL.port;
    NSUInteger portNumber = 0;
    NSString *host = request.URL.host;
    NSString *scheme = request.URL.scheme;
    BOOL shouldCheckPort = false;
    
    if (port != nil) {
        portNumber = port.unsignedIntegerValue;
        shouldCheckPort = !(portNumber == 443 || portNumber == 80);
    }
    
    if (scheme.length > 0 && host.length > 0){
        originalString = [NSString stringWithFormat:@"%@://%@", scheme,host];
    } else if (host.length > 0) {
        originalString = request.URL.host;
    } else{
        originalString = request.URL.absoluteString;
        shouldCheckPort = false;
    }
    
    if(shouldCheckPort) {
        originalString = [NSString stringWithFormat:@"%@:%u",originalString, portNumber];
    }
    

    return [self URLRegex:domain matchesRequestString:originalString];
}

+ (BOOL)URLRegex:(NSString *)urlRegex matchesRequestString:(NSString *)requestString
{
    NSError *error = nil;
    NSString *preprocessedURL = urlRegex;
    if (!([preprocessedURL hasPrefix:@"http"] || [preprocessedURL hasPrefix:@"ftp"])) {
        preprocessedURL = [kSchemeRegex stringByAppendingString:preprocessedURL];
    }
    
    BOOL shouldAddTrailingRegex = false;
    if([preprocessedURL hasSuffix:kWildcard]) {
        preprocessedURL = [preprocessedURL substringToIndex:preprocessedURL.length-1];
        shouldAddTrailingRegex = true;
        
    }
    
    preprocessedURL = [preprocessedURL stringByReplacingOccurrencesOfString:kWildcard
                                                                 withString:kDomainRegex];
    
    if(shouldAddTrailingRegex) {
        preprocessedURL = [preprocessedURL stringByAppendingString:kTrailingDomainRegex];
    }
    
    // Add start and end regex markers
    preprocessedURL = [@"^" stringByAppendingString:preprocessedURL];
    preprocessedURL = [preprocessedURL stringByAppendingString:@"$"];
    
    
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:preprocessedURL
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    NSUInteger matches = [regex numberOfMatchesInString:requestString
                                                options:NSMatchingAnchored
                                                  range:NSMakeRange(0, requestString.length)];
    
#if DEBUG
    NSLog(@"[%@] [%@]     ...........%d",requestString,regex,matches);
#endif
    return matches > 0;
}

- (BOOL)proxyShouldHandleRequest:(NSURLRequest *)request
{
    
    if (!request) {
        /* Safeguard incase request is nil */
        return NO;
    }
    
    NSArray *allowedDomains = [AWProxy sharedInstance].appTunnelDomains;
    AWLogInfo(@"Allowed Domains: %@",allowedDomains);
    
    if (allowedDomains.count <= 0){
        AWLogVerbose(@"Allowing %@ b/c allowed domains count is <= 0", request.URL.host);
        return YES;
    }
    
    if ([AWProxyHandler domain:magReachabilityTestURL matchesRequest:request]) {
        //Always allow MAG Reachability test
        return YES;
    }
    
    BOOL retVal = NO;
    
    for (NSString *domain in allowedDomains) {
        
        BOOL reqAllowed = [AWProxyHandler domain:domain matchesRequest:request];
        AWLogInfo(@"Is %@ allowed: %d", domain, reqAllowed);
        
        retVal = retVal || reqAllowed;
        if(reqAllowed){
            break;
        }
    }
    
    if(!retVal) {
        
        NSArray *components = [request.URL.host componentsSeparatedByString:@"."];
        retVal = components.count==1;
    }
    
    AWLogInfo(@"************** Allowing Proxy to handle %@: %@",request.URL.host,retVal?@"YES":@"NO");
    return retVal;
}

- (void)proxyConnectionFailed:(AWProxyFailureReason)reason
{
    if ([self.delegate respondsToSelector:@selector(proxyConnectionFailed:)])
        [self.delegate proxyConnectionFailed:reason];
}

-(void)reFetchMAGCert:(NSNotification *)notification{
    
    AWLogInfo(@"Notification from forwader %@",notification.userInfo.description);
    if (notification.userInfo) {
        NSInteger magErrorCode = [notification.userInfo[AWMAGCertFetchFailureErrorCode] integerValue];
        AWLogDebug(@"AWRefetchMAGCertificate - MAG error code %ld",(long)magErrorCode);
        if ([AWProxy shouldRefetchMAGCert:magErrorCode]) {
            fetchMAGCertificate = YES;
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AWRefetchMAGCertificate
                                                          object:nil];
        }
    } else {
        AWLogDebug(@"No error info present in AWRefetchMAGCertificate notification");
    }
}

#if 0
-(BOOL)canConnectToLocalProxy {
    
    AWLogInfo(@"check connectivity to local proxy");
    struct addrinfo sock_address, *result;
    int sockfd;
    
    memset(&sock_address, 0, sizeof sock_address);
    sock_address.ai_family = AF_INET;
    sock_address.ai_socktype = SOCK_STREAM;
    
    NSInteger localPort = [[AWForwarderService sharedInstance] localProxyPort];
    const char *portString =[NSString stringWithFormat:@"%d",localPort].UTF8String;
    
    getaddrinfo("localhost", portString, &sock_address, &result);
    
    
    sockfd = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if(sockfd == -1) {
        return false;
    }
    
    int conResult = connect(sockfd, result->ai_addr, result->ai_addrlen);
    
    __unused int closeResult = close(sockfd);
    BOOL canConnect = conResult != -1;
    
    AWLogInfo(@"%@ connect to local proxy",canConnect?@"Can":@"Cannot");
    return canConnect;
}

#endif



#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    
    AWLogInfo(@"MAG reachability response %@", response);
    if (response) {
        NSInteger statusCode = [(NSHTTPURLResponse*)response statusCode];
        NSInteger awErrorCode = [[[(NSHTTPURLResponse*)response allHeaderFields] objectForKey:@"aw-error-code"] integerValue];
        
        if (407 == statusCode &&
            [AWProxy shouldRefetchMAGCert:awErrorCode]){

            fetchMAGCertificate = NO;
            [self fetchMagCert];
            completionHandler(NSURLSessionResponseCancel);
            return;
        }
    }
    
    completionHandler(NSURLSessionResponseAllow);
}


#pragma mark NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    AWLogInfo(@"MAG reachability completed %@", error);
    
    // We should refetch the MAG certificate only if the connection fails. If connection succeeds, then MAG cert worked and there shouldn't be any need to refetch the cert.
    if (!error) {
        [self returnWithSuccess:self.didStartLocalProxy andError:self.startLocalProxyError];
    } else {
        if(fetchMAGCertificate){
            AWLogInfo(@"MAG reachability, need to fetch MAG cert");
            fetchMAGCertificate = NO;
            [self fetchMagCert];
        }else {
            if(error.code != NSURLErrorCancelled)  {
                [self returnWithSuccess:self.didStartLocalProxy andError:self.startLocalProxyError];
            }
        }
    }
}

@end
