//
//  AWForwarderService.m
//  AirWatch
//
//  Created by Vishal Patel on 11/19/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */


#import "notify.h"

#import "AWContentFilter.h"
#import "AWForwarderService.h"
#import "AWProxy.h"
#import "AWProxyErrors.h"
#import "AWProxyHandler.h"
#import "AWTunnelLogger.h"

#import "Fuji.h"
#import "FNInetPriv.h"
#import "FNProxySupportPriv.h"

#import "VHProxyControl.h"
#import "VHProxyService.h"
#import "VHProxyServerSocket.h"

#import <AWTunnel/AWTunnel-Swift.h>

@import AWHelpers;
@import AWLocalization;

NSString *const kAWForwarderServiceProxyStarted = @"AWForwarderServiceProxyStarted";

@implementation AWForwarderService


+(AWForwarderService *) sharedInstance
{
    static dispatch_once_t onceToken;
    static AWForwarderService *instance = nil;
    
    dispatch_once(&onceToken, ^{
        
        instance = [[AWForwarderService alloc] init];
#ifdef ENABLE_PROXY
        extern void HookCore_Init(void);
        HookCore_Init();
#endif
        
    });
    
    return instance;
}



-(BOOL) startForwarderService
{
#ifdef ENABLE_PROXY
    @synchronized(self) {
        
        VHProxyService *proxyService = SharedProxyService();
        
        if ([proxyService isServiceEnabled]) {
            //Service already enabled.  Just update the hooks
            [self updateHookForForwarderSettingsWithProxy:YES withContentFilter:YES];
            return YES;
        }
        
        __unsafe_unretained AWForwarderService *blkSelf = self;
        dispatch_semaphore_t proxySemaphore = dispatch_semaphore_create(0);
        __block BOOL didConfigureProxy = NO;
        [proxyService startWithProxyHost:nil proxyPort:0 authenticateCertificates:NO onStarted:^(NSString *localHost, NSInteger localPort, NSError *error) {
            
            if (error != nil) {
                // There was an error starting the proxy
                // make sure we don't have any second level hooks set
                // and report error
                
                [blkSelf disableProxy];

                if(![[NSBundle mainBundle] isExtensionBundle])
                {
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:AWSDKLocalizedString(@"Ok", nil)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:nil];
                    KeyWindowAlert *alert = [[KeyWindowAlert alloc] initWithTitle:AWSDKLocalizedString(@"ErrorTitle", nil)
                                                                          message:[NSString stringWithFormat:@"%@ [%d]", AWSDKLocalizedString(@"ErrorAlertProxy", nil), AWProxyErrorFujiProxyNotStart]
                                                                          actions:@[okAction]];
                    [alert show];
                }
                else
                {
                    
#if 0
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:AWSDKLocalizedString(@"Ok", nil)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:nil];
                    KeyWindowAlert *alert = [[KeyWindowAlert alloc] initWithTitle:AWSDKLocalizedString(@"ErrorTitle", nil)
                                                                          message:[NSString stringWithFormat:@"%@ [%d]", AWSDKLocalizedString(@"ErrorAlertProxy", nil), AWProxyErrorFujiProxyNotStart]
                                                                          actions:@[okAction]];
                    [alert show];
#else
#warning "TODO: Delegate to SDK to show the AWProxyErrorFujiProxyNotStart alert"
                    AWLogWarning(@"NYI: Delegate to SDK to show the AWProxyErrorFujiProxyNotConfigured alert");
                    AWLogError(@"Error on proxy setup: %d", AWProxyErrorFujiProxyNotConfigured);
#endif
                }

                dispatch_semaphore_signal(proxySemaphore);
                return;
            }
            
            blkSelf.localProxyPort = localPort;
            
            
            _FNProxySupportInit();
            
            if (([[UIDevice currentDevice].systemVersion intValue] >= 9) &&
                (!objc_getClass("ABURLProtocol") &&
                 !objc_getClass("AWBrowserAppDelegate"))){
                    
                    //DO NOT DO THIS FOR BROWSER..
                    
                    NSString *proxyAddress = @"127.0.0.1";
                    NSDictionary *settings = @{
                                               /* Works for NSURLSession dataTask
                                                * Works for NSURLConnection */
                                               (NSString *)kCFNetworkProxiesHTTPEnable: @YES,   /* or @NO */
                                               (NSString *)kCFNetworkProxiesHTTPProxy: proxyAddress,
                                               (NSString *)kCFNetworkProxiesHTTPPort: @(localPort),
                                               @"HTTPProxyAuthenticated": @"1",
                                               @"HTTPUser": @"user",
                                               /* ??? password stored in keychain with account name
                                                * "http-proxy-username" and where http://<proxyAddress>:<proxyPort> */
                                               
                                               /* Works NSURLSession dataTask
                                                * Works for NSURLConnection */
                                               @"HTTPSEnable": @YES,    /* or @NO */
                                               @"HTTPSProxy": proxyAddress,
                                               @"HTTPSPort": @(localPort),
                                               @"HTTPSProxyAuthenticated": @"1",
                                               @"HTTPSUser": @"user",   /* password stored in keychain */
                                               /* ??? password stored in keychain with account name
                                                * "https-proxy-username" and where https://<proxyAddress>:<proxyPort> */
                                               
                                               /* not exported on iOS */
                                               @"ExceptionsList": @[ @"*.local",
                                                                     @"169.254/16",
                                                                     proxyAddress,
                                                                     [NSString stringWithFormat:@"%@:%ld", proxyAddress, (long)localPort],
                                                                     [[[AWServer sharedInstance] deviceServicesURL] host] ? [[[AWServer sharedInstance] deviceServicesURL] host] : @"localhost"],
                                               @"excludeSimpleHostnames": @NO,
                                               @"FTPPassive": @YES
                                               };
                    
                    _FNProxySetOverrideSystemProxySettings((__bridge CFDictionaryRef) settings);
                }
            
            
            _FNProxySupportError ret = [blkSelf updateHookForForwarderSettingsWithProxy:YES withContentFilter:YES];
            if(ret == _kFNProxySupportErrorSuccess) {
                didConfigureProxy = YES;
            }
            
            if(!didConfigureProxy) {
                // Proxy was not configured properly
                // disable the proxy and report error

                if(![[NSBundle mainBundle] isExtensionBundle])
                {
                    
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:AWSDKLocalizedString(@"Ok", nil)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:nil];
                    KeyWindowAlert *alert = [[KeyWindowAlert alloc] initWithTitle:AWSDKLocalizedString(@"ErrorTitle", nil)
                                                                          message:[NSString stringWithFormat:@"%@ [%d]", AWSDKLocalizedString(@"ErrorAlertProxy", nil), AWProxyErrorFujiProxyNotConfigured]
                                                                          actions:@[okAction]];
                    [alert show];
                }
                else
                {
#if 0
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:AWSDKLocalizedString(@"Ok", nil)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:nil];
                    KeyWindowAlert *alert = [[KeyWindowAlert alloc] initWithTitle:AWSDKLocalizedString(@"ErrorTitle", nil)
                                                                          message:[NSString stringWithFormat:@"%@ [%d]", AWSDKLocalizedString(@"ErrorAlertProxy", nil), AWProxyErrorFujiProxyNotConfigured]
                                                                          actions:@[okAction]];
                    [alert show];
#else
#warning "TODO: Delegate to SDK to show the AWProxyErrorFujiProxyNotConfigured alert"
                    AWLogWarning(@"NYI: Delegate to SDK to show the AWProxyErrorFujiProxyNotConfigured alert");
                    AWLogError(@"Error on proxy setup: %d", AWProxyErrorFujiProxyNotConfigured);
#endif
                }

                [blkSelf disableProxy];
            }
            
            //Check to make sure CFNetworkCopySystemProxySettings is setting the proper proxy settings if not resend notify.
            CFDictionaryRef currentProxySettings = CFNetworkCopySystemProxySettings();
            NSDictionary *currentSettings = (__bridge_transfer NSDictionary*)currentProxySettings;
            NSInteger proxyHttpPort = [[currentSettings valueForKey:@"HTTPPort"] integerValue];
            
            if(proxyHttpPort != localPort)
            {
                //Incase CFNetworkCopySystemProxySettings has not updated its cache call notify again.
                notify_post("com.apple.system.config.network_change");
            }
            
            if([[UIDevice currentDevice].systemVersion intValue] >= 9)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:kAWForwarderServiceProxyStarted object:nil userInfo:nil];
            }
            
            dispatch_semaphore_signal(proxySemaphore);
            
        }]; //end [proxy startwithProxyHost]
        
        dispatch_semaphore_wait(proxySemaphore, DISPATCH_TIME_FOREVER);
        
        return didConfigureProxy;
    }
#else
    return NO;
#endif
}



-(void) disableProxy
{
    _FNProxySupportSetProxySettings(NULL, FALSE, TRUE, NULL, NULL, NULL);

    if ([[UIDevice currentDevice] isAtleastOperatingSystemVersionWithMajor:9 minor:0 patch:0]){
        _FNProxySetOverrideSystemProxySettings(NULL);
    }
}

-(_FNProxySupportError) updateHookForForwarderSettingsWithProxy:(BOOL) withProxy withContentFilter:(BOOL) withContentFilter
{
    NSMutableArray *whitelist = NULL;
    NSArray *entries = NULL;
    
    //If standard proxy with pac file then only hook do not start service.
    whitelist = [[NSMutableArray alloc] initWithArray: @[
                                                         [NSString stringWithFormat:@"%@", [[[AWServer sharedInstance] deviceServicesURL] host]]
                                                         ]];
    
    /* Add proxy information */
    if (withProxy && [[AWProxy sharedInstance] host])
    {
        [whitelist addObject:[NSString stringWithFormat:@"%@", [[AWProxy sharedInstance] host]]];
    }
    
    /* Add content filtering information */
    NSString * websensePacAddress = [[AWContentFilter sharedInstance] websensePacAddress];
    if (withContentFilter && websensePacAddress && [websensePacAddress length] > 0)
    {
        NSURL *websenseHost = [NSURL URLWithString:websensePacAddress];
        
        if([websenseHost host]) {
            [whitelist addObject:[NSString stringWithFormat:@"%@", [websenseHost host]]];
        }
    }
    
    NSString *localProxy = [NSString stringWithFormat:@"127.0.0.1:%ld", (long)self.localProxyPort];
    
    entries = @[
                [NSString stringWithFormat:@"https://user@%@",localProxy],
                [NSString stringWithFormat:@"http://user@%@",localProxy],
                [NSString stringWithFormat:@"ftp://user@%@",localProxy]
                ];
    
    
    return _FNProxySupportSetProxySettings((__bridge CFArrayRef)entries, 0, 0,
                                           (__bridge CFArrayRef)whitelist,
                                           NULL,
                                           NULL);
}


-(void) stopForwarderServiceWithCompletion: (dispatch_block_t) completion
{
    @synchronized(self) {
        [self disableProxy];
        VHProxyService *proxyService = SharedProxyService();
        [proxyService stopWithCompletion:completion];
    }
}

-(void) stopProxyWithCompletion: (dispatch_block_t) completion
{        _FNProxySupportUpdateProxyForwardList(NULL);
    
    /* Check to see if we can shut down forwarder */
    NSString * websensePacAddress = [[AWContentFilter sharedInstance] websensePacAddress];
    if(!websensePacAddress ||
       [websensePacAddress length] <= 0)
    {
        [self stopForwarderServiceWithCompletion:completion];
        return;
    }
    if(completion) completion();
}
-(void) stopContentFilterWithCompletion: (dispatch_block_t) completion
{
    _FNProxySupportUpdateContentFilteringForwardList(NULL);
    
    /* Check to see if we can shut down forwarder */
    if(![[AWProxy sharedInstance] isEnabled])
    {
        [self stopForwarderServiceWithCompletion:completion];
        return;
    }
    
    if(completion) completion();
}


@end
