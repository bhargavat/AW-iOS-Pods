/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

//
//  AWF5ProxyController.mm
//  Airwatch
//
//  Created by Sijo Paulose on 7/23/13.
//

#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
#import <AWTunnel/AWTunnel.h>
#import <AWTunnel/AWTunnel-Swift.h>

#import "AWF5ProxyController.h"
//#import "AWDeviceInfo.h"
//#import "UIDevice+AirWatch.h"
#import "AWProxy.h"
#import "AWProxy_F5.h"
#import "AWProxyErrors.h"
//#import "AWSDKErrors.h"
//#import "AWSDKLocalizationBundle.h"
//#import "AWKeychain.h"
#import <Security/Security.h>

#import <sys/types.h>
#include <arpa/inet.h>
#import "TunnelProxyLib.h"

#import <AWLog/AWLogPrivate.h>

#define kAWProxyValidSessionTime (60*1000)//60 seconds
#define kAWF5SesssionCheckTimerInterval 60 //60 secs
#define kAWF5MaxInvalidLogonAttempts 3 
#define kAWF5SDKUniversalIdentifier @"com.air-watch.ios.application"

static NSString *kF5userAgentString     = nil;

@interface AWF5ProxyController (){

    NSTimer     *f5SessionCheckTimer;
    NSInteger    f5SessionInvalidAttempts;
}
@property(nonatomic, assign, readonly) BOOL authenticated;

- (void)handleF5SessionExpiry;

- (BOOL)checkAndRenewF5SessionInNeededWithError:(NSError**)error
                                      ifRecheck:(BOOL)recheck;

- (NSString*)deviceF5SessionKey:(NSError**) error;

- (void)setDeviceF5SessionKey:(NSString*)sessionKey
                        error:(NSError**)error;

@end

static int certificate_verify(SecTrustRef trustRef, void* context)
{
    int res = 0;
    return res; // Now bypassing cert validation in Client side.Its not needed..
}
static void session_expired_handler(const char* szSessionId, void* context)
{
    AWF5ProxyController *f5ProxyController = NULL;
    f5ProxyController = (__bridge AWF5ProxyController*)context;
    log(debug: @"F5 Session expired. ***** Expired Session Id: %ss, Context: %p", szSessionId, context);
    AWLogInfo(@"F5 Session expired.");
    [f5ProxyController handleF5SessionExpiry];
}
@implementation AWF5ProxyController

+ (AWF5ProxyController *)sharedInstance
{
    static AWF5ProxyController *_sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[AWF5ProxyController alloc] init];
    });
    return _sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _isEnabled = NO;
        _authenticated = NO;
        f5SessionInvalidAttempts = 0;
    }
    return self;
}
- (void)dealloc
{
    f5SessionCheckTimer = nil;
}

- (BOOL)startF5ProxyWithError:(NSError**)error
{
    NSError *outErr = nil;
    _isEnabled =  YES;
    if([[[AWProxy sharedInstance] host] length] == 0 ||
       ([[AWProxy sharedInstance] httpsPort] == 0)){
        
        outErr = AWErrorMacro(AWProxyErrorDomain,
                              AWProxyErrorProxyIsNotConfigured,
                              AWSDKLocalizedString(@"Invalid F5 Proxy configuration.",nil),
                              AWSDKLocalizedString(@"Invalid F5 Proxy configuration. Please check your f5 proxy host and port.",nil),
                              AWSDKLocalizedString(@"Invalid F5 Proxy configuration.",nil));
        _isEnabled = NO;
    }
    if(_isEnabled){
        
        [self initializeF5proxy];
        outErr = nil;
        _isEnabled = [self authenticateF5SessionWithError:&outErr];//Authenticate on Start
        if(_isEnabled){
            _authenticated = YES;
            _isEnabled = [self checkAndRenewF5SessionInNeededWithError:&outErr ifRecheck:YES];
        }
    }
    if (error)
    {
        *error = outErr;
    }
    if(_isEnabled){
    
        [self setupF5SesssionCheckTimer];
    }
    return _isEnabled;
}

- (void)setupF5SesssionCheckTimer{

    if([f5SessionCheckTimer isValid]){
    
        [f5SessionCheckTimer invalidate];
    }
    
    f5SessionInvalidAttempts = 0;
    f5SessionCheckTimer = [NSTimer scheduledTimerWithTimeInterval:kAWF5SesssionCheckTimerInterval
                                                           target:self
                                                         selector:@selector(f5SessionTimerFired)
                                                         userInfo:nil
                                                          repeats:YES];
}


-(BOOL)authenticateF5SessionWithError:(NSError**)error
{
    NSError *outErr = nil;
    
    /*
    AWF5ProxyAuthTypeUsernamePassword  //Verified using F5 test proxy.     
    AWF5ProxyAuthTypeCertificate            // Not verified this scenario. Fails with GE and F5 test proxies.
    AWF5ProxyAuthTypeUsernamePasswordCertificate //Verified using F5 and GE. Working.
     */
    
    BOOL status = YES;
    AWF5AuthenticationMode authType = [[AWProxy sharedInstance] f5ProxyAuthType];

    if( (AWF5AuthenticationModeCertificate ==  authType) || (AWF5AuthenticationModeUsernamePasswordAndCertificate ==  authType) ){
        
        status = [self clientCertificateAuthenticationWithError:&outErr];

    }
    if(status){
        
        if( (AWF5AuthenticationModeUsernameAndPassword ==  authType) || (AWF5AuthenticationModeUsernamePasswordAndCertificate ==  authType) ){
            
            status = [self userNamePasswordAuthenticationWithError:&outErr];

        }
    }
    if (error)
    {
        *error = outErr;
    }
    return status;
}
- (void)f5SessionTimerFired
{
    if(!_isEnabled){
        
        if([f5SessionCheckTimer isValid]){
        
            [f5SessionCheckTimer invalidate];
        }
        return;
    }
    
    @synchronized (self) {
        BOOL sessionValid = [self checkAndRenewF5SessionInNeededWithError:nil ifRecheck:NO];
        if(!sessionValid){
            
            f5SessionInvalidAttempts++;
            if(f5SessionInvalidAttempts == kAWF5MaxInvalidLogonAttempts){
             
                if([f5SessionCheckTimer isValid]){
                    
                    [f5SessionCheckTimer invalidate];
                }
            }
            _authenticated = NO;
        }else{
            
            f5SessionInvalidAttempts = 0;
        }
    }
}

- (void)stopF5proxy
{
    f5_logout();
    f5_deinit();
    _isEnabled = NO;
    _authenticated = NO;
    f5SessionInvalidAttempts = 0;
}
- (void)handleF5SessionExpiry
{
    _authenticated = NO;
    [self checkAndRenewF5SessionInNeededWithError:nil ifRecheck:YES];
}
- (void)initializeF5proxy
{    
    int iniStaus = 0;
    iniStaus = f5_init();
    
    const char* v = f5_get_version();
    AWLogInfo(@"F5 Library Version: %s", v);
    
    F5_DeviceInfo deviceInfo;
    
    deviceInfo.szModel = [[[UIDevice currentDevice] model]
                          cStringUsingEncoding:NSMacOSRomanStringEncoding];
    deviceInfo.szOSVersion = [[[UIDevice currentDevice] systemVersion]
                              cStringUsingEncoding:NSMacOSRomanStringEncoding];
    deviceInfo.szIMEI = "";
    deviceInfo.szMACAddress = [[[UIDevice currentDevice] WiFiMACAddress]
                               cStringUsingEncoding:NSMacOSRomanStringEncoding];
    deviceInfo.szUniqueId = [[[AWTunnelService sharedInstance] deviceUDID] cStringUsingEncoding:NSMacOSRomanStringEncoding];
    deviceInfo.szSerialNumber = "";
    deviceInfo.isJailbroken = 0;
    deviceInfo.szVendorData = "";

    //We require the f5 session for all the applications in this device.
    deviceInfo.szAppId = [kAWF5SDKUniversalIdentifier
                          cStringUsingEncoding:NSMacOSRomanStringEncoding];
    deviceInfo.szAppVersion = "1.0";    
    
    f5_set_device_info(&deviceInfo);
    
    //Not settings user agent 
     //Set User Agent
    //f5_set_user_agent([[self userAgent] cStringUsingEncoding:NSMacOSRomanStringEncoding]);
    
    f5_set_dns_split_scope("*",NULL);//Do we have to control from Client side ?
    
    if (0 != f5_set_cert_verify(certificate_verify, (__bridge  void*)self)) {
        AWLogError(@"%@", @"Failed to set certificate verify callback");
    }
    else{
        AWLogVerbose(@"Succedded to set certificate verify callback");
    }
    if (0 != f5_set_invalid_session_callback(session_expired_handler, (__bridge  void*)self)) {
        AWLogError(@"%@", @"Failed to set expired session callback");
    }    
}
- (BOOL)clientCertificateAuthenticationWithError:(NSError**)error
{
    NSError *certAuthErr = nil;
    BOOL success = YES;
    NSData *p12Data = [[AWProxy sharedInstance] p12CertDataForF5];
    NSString *p12PassPhrase = [[AWProxy sharedInstance] passPhraseForF5Cert];
    if( (success) &&  p12Data )
    {
        if (0 != f5_set_identity_pkcs12([p12Data bytes], [p12Data length],
                                        [p12PassPhrase cStringUsingEncoding:NSMacOSRomanStringEncoding])) {
            AWLogError(@"%@", @"Failed to set client identity");
            certAuthErr = AWErrorMacro(AWProxyErrorDomain,
                                  AWProxyErrorF5FailedToSetClientIdentity,
                                  AWSDKLocalizedString(@"Failed to set F5 Client Certificate.",nil),
                                  AWSDKLocalizedString(@"Failed to set F5 Client Certificate. The p12 data is invalid.",nil),
                                  nil);
            
            success = NO;
        }else{
            AWLogInfo(@"*** F5 Client Certificate Authentication using p12 dataSUCCESS ***");
        }
    }else{
        success = NO;
    }
    if (error)
    {
        *error = certAuthErr;
    }
    return success;
}

-(BOOL)userNamePasswordAuthenticationWithError:(NSError**)error
{
    NSError *unamePwdAuthError = nil;
    
    BOOL success = YES;
    
    const char* host     = [[[AWProxy sharedInstance] host] cStringUsingEncoding:NSMacOSRomanStringEncoding];
    
    
    const char* userName = [[[AWProxy sharedInstance] username] cStringUsingEncoding:NSMacOSRomanStringEncoding];
    const char* passWord = [[[AWProxy sharedInstance] password] cStringUsingEncoding:NSMacOSRomanStringEncoding];

    
    log(debug: @"F5Proxy Host %s",host);
    log(debug: @"F5Proxy UserName %s",userName);
    log(debug: @"F5Proxy PassWord %s",passWord);
    
    @synchronized(self) {
        if (0 != f5_logon(host, [[AWProxy sharedInstance] httpsPort], userName, passWord)) {
            AWLogError(@"%@", @"Authentication Failed");
            unamePwdAuthError = AWErrorMacro(AWProxyErrorDomain,
                                             AWProxyErrorF5UsernameAuthFailed,
                                             AWSDKLocalizedString(@"F5 proxy logon failed.",nil),
                                             AWSDKLocalizedString(@"F5 proxy logon failed. Failed to authenticate using  F5 Proxy UserName/Password.",nil),
                                             nil);
            success = NO;
        } else {
            AWLogVerbose(@"*** F5 UserName/Password Authentication SUCCESS ***");
        }
        
    }
    
    if (error)
    {
        *error = unamePwdAuthError;
    }
    return success;
}

- (BOOL)checkAndRenewF5SessionInNeededWithError:(NSError**)error
                                      ifRecheck:(BOOL)recheck
{
    NSError *sessionError = nil;

    BOOL success = YES;
    NSString *oldSessionId = [self deviceF5SessionKey:nil];
   
    BOOL startSessionCheckTimer = NO;
    int res = 0;
    unsigned long timeToLive = 0;
    char cur_sessionId[MAX_SESSION_LEN];
    if([oldSessionId length] > 0)
    {
        NSInteger port = [[AWProxy sharedInstance] httpsPort];
        AWLogVerbose(@"Checking f5 session validity");
        @synchronized (self) {
            res = f5_check_session([[[AWProxy sharedInstance] host] cStringUsingEncoding:NSMacOSRomanStringEncoding],
                                   port,
                                   [oldSessionId cStringUsingEncoding:NSMacOSRomanStringEncoding],
                                   &timeToLive);
            
        }
        if (0 != res) {
            AWLogError(@"%@ - Error code: %d", @"Failed to check f5 session lifetime", res);
            sessionError = AWErrorMacro(AWProxyErrorDomain,
                                  AWProxyErrorF5FailedToCheckSessionLifetime,
                                  AWSDKLocalizedString(@"Failed to check F5 session lifetime.",nil),
                                  AWSDKLocalizedString(@"Failed to check F5 session lifetime. Check your f5 Proxy Configuration.",nil),
                                  nil);
            success = NO;
        } else {
            AWLogVerbose(@"F5 Session time to live: %lu", timeToLive);
        }
    }else{
    
        AWLogVerbose(@"No Old F5 Session..So get new session from F5.");
        timeToLive = 0;
    }
    
    // Re-use old session if it's still valid for more than 60 secs
    if( success &&  (timeToLive < kAWProxyValidSessionTime) ) {
        
        AWLogVerbose(@"%@", @"Establishing New F5 Session");
        [self setDeviceF5SessionKey:nil error:nil];
        BOOL loggedIn = YES;
        if(!_authenticated){
            loggedIn = [self authenticateF5SessionWithError:&sessionError];
            startSessionCheckTimer = YES;
        }
        if (!loggedIn) {
            AWLogError(@"%@", @"F5 Authentication Failed");
            success = NO;
        }
        else
        {
            int i = f5_get_session(cur_sessionId, MAX_SESSION_LEN);
            AWLogVerbose(@"New F5 Session Id: %s - %d", cur_sessionId, i);
            NSString *activeSessionId = [NSString stringWithUTF8String:cur_sessionId];
            AWLogVerbose(@"Active F5 SessionId %@",activeSessionId);
            
            [self setDeviceF5SessionKey:activeSessionId error:nil];
        }
    } else {
        
        if(recheck){
            
            @synchronized(self) {
                
                oldSessionId = [self deviceF5SessionKey:nil];

                if (0 != f5_set_session([[[AWProxy sharedInstance] host] cStringUsingEncoding:NSMacOSRomanStringEncoding],
                                        [[AWProxy sharedInstance] httpsPort],
                                        [oldSessionId cStringUsingEncoding:NSMacOSRomanStringEncoding])) {
                    AWLogError(@"%@", @"Set F5 Session Failed");
                    sessionError = AWErrorMacro(AWProxyErrorDomain,
                                                AWProxyErrorF5FailedToSetSession,
                                                AWSDKLocalizedString(@"Failed to set F5 session.",nil),
                                                AWSDKLocalizedString(@"Failed to set F5 session. Check your f5 Proxy Configuration.",nil),
                                                nil);
                    _authenticated = NO;
                } else {
                    AWLogVerbose(@"%@", @"Reusing existing F5 session");
                }
            }
        }
        //Else no need to set Session Again.
    }
    
    if(success && recheck) {
    
        // check session again
        
        @synchronized(self) {
            f5_get_session(cur_sessionId, MAX_SESSION_LEN);
            if (0 != f5_check_session([[[AWProxy sharedInstance] host] cStringUsingEncoding:NSMacOSRomanStringEncoding],
                                      [[AWProxy sharedInstance] httpsPort],
                                      cur_sessionId,
                                      &timeToLive)) {
                AWLogError(@"%@", @"Failed to check F5 session lifetime");
                success = NO;
            }
        }
        AWLogVerbose(@"Current f5 session time to live: %lu", timeToLive);
    }
    if (error)
    {
        *error = sessionError;
    }
    if(success && startSessionCheckTimer){
    
        //Restart Timer
        [self setupF5SesssionCheckTimer];
    }
    return success;
}

-(NSString *)userAgent{
    
    if(!kF5userAgentString){
        if ([[[UIDevice currentDevice] model] hasPrefix:@"iPad"]) {
            kF5userAgentString = @"Mozilla/5.0 (iPad; CPU OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Mobile/9B206";
        }else{
            
            kF5userAgentString = @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) "
            "Version/5.1 Mobile/9A334 Safari/7534.48.3";
        }
    }
    return kF5userAgentString;
}

- (int)socketHandleForRequest:(NSURLRequest *)request
                    withError:(NSError**)error
{
    NSString *urlStr = request.URL.absoluteString;
    NSString *urlSheme = request.URL.scheme;
    BOOL httpsRequest = ([urlSheme caseInsensitiveCompare:@"https"] == NSOrderedSame);
    
    NSURL *url = [NSURL URLWithString:urlStr];
    const char *host = [url.host cStringUsingEncoding:NSMacOSRomanStringEncoding];
    struct addrinfo* ai = NULL;
    addrinfo ai_hints = {
        .ai_flags = AI_ALL,
        .ai_family = AF_INET,
        .ai_socktype = SOCK_STREAM,
    };
    
    BOOL canConnect = YES;
    NSError *f5Err = nil;
    int res = f5_getaddrinfo(host,
                             [url.scheme cStringUsingEncoding:NSMacOSRomanStringEncoding],
                             &ai_hints,
                             &ai);
    
    if(res || !ai || ai->ai_addrlen != sizeof(sockaddr_in)) {
        
        canConnect = NO;
        f5Err = AWErrorMacro(AWProxyErrorDomain,
                              AWProxyErrorF5DNSResolutionFailed,
                              AWSDKLocalizedString(@"DNS resolution failed.",nil),
                              AWSDKLocalizedString(@"DNS resolution failed.",nil),
                              nil);
    } else {
         log(debug: @"AddressInfo=> %s : %s\n",
         host,
         inet_ntoa(((sockaddr_in*)ai->ai_addr)->sin_addr));
    }
    int fd = 0;
    if(canConnect){
        
        fd = socket(PF_INET, SOCK_STREAM, 0);
        sockaddr_in sin = {0};
        sin.sin_family = AF_INET;
        
         sin.sin_port = htons([url.port integerValue]);
        
        if (!sin.sin_port) {
            if(httpsRequest){
                sin.sin_port = htons(443);
            }else{
                sin.sin_port = htons(80);
            }
        }
        
        sin.sin_addr = ((sockaddr_in*)ai->ai_addr)->sin_addr;
        res = f5_connect(fd, (sockaddr*)&sin, sizeof(sin));
        
        f5_freeaddrinfo(ai);
        
        if(res) {
            
            f5Err = AWErrorMacro(AWProxyErrorDomain,
                                 AWProxyErrorF5FailedToConnect,
                                 AWSDKLocalizedString(@"Connection Error.",nil),
                                 AWSDKLocalizedString(@"Failed to establish connection with backend server.",nil),
                                 nil);
        } else {
            AWLogVerbose(@"F5 Connection with backend server successfully established\n");
        }
    }
    
    if (error)
    {
        *error = f5Err;
    }
    
    return fd;
}

- (NSString*)deviceF5SessionKey:(NSError**) error
{
//    NSString *f5SessionKey = nil;
//    NSString *account = kAWF5SDKUniversalIdentifier;
//    NSString *service = [NSString stringWithFormat:@"%@F5Session:%@",kAWF5SDKUniversalIdentifier,
//                         [[AWProxy sharedInstance] host]];//To Ensure the session is of same host
//	NSString *accessGroup = nil;
//    
//    NSData *sessionKeyData = [AWKeychain dataForAccount:account
//                                                service:service
//                                            accessGroup:accessGroup
//                                                  error:error];
//    if(sessionKeyData){
//        
//        f5SessionKey =  [[NSString alloc] initWithData:sessionKeyData
//                                               encoding:NSUTF8StringEncoding];
//    }
//    return f5SessionKey;
    return [[AWTunnelService sharedInstance] F5SessionKey];
}

- (void)setDeviceF5SessionKey:(NSString*)sessionKey error:(NSError**)error
{
//    NSString *account = kAWF5SDKUniversalIdentifier;
//    NSString *service = [NSString stringWithFormat:@"%@F5Session:%@",kAWF5SDKUniversalIdentifier,
//                         [[AWProxy sharedInstance] host]];
//    NSData *sessionKeyData = [sessionKey dataUsingEncoding:NSUTF8StringEncoding];
//	NSString *accessGroup = nil;
//	[AWKeychain setDataForAccount:sessionKeyData account:account
//                          service:service accessGroup:accessGroup error:error];
    [[AWTunnelService sharedInstance] setF5SessionKey:sessionKey];
}

@end
#endif
