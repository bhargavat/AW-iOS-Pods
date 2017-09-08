//
//  AWContentFilterHandler.m
//  AirWatch
//
//  Created by Vishal Patel on 11/19/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

#import "AWContentFilterHandler.h"
#import "AWContentFilter.h"
#import "AWTunnelLogger.h"

#import <AWTunnel/AWTunnel-Swift.h>

//FIXME: unified error information
NSString *const AWSDKErrorDomain = @"com.vmware.air-watch.sdk.tunnel";

@interface AWContentFilterHandler()<AWContentFilterDelegate>
{
    BOOL _isSettingUpProxy;
}

- (void)returnWithSuccess:(BOOL) success andError:(NSError*)error;
@property (nonatomic,copy) contentFilterSetupCompletion completionBlock;

@end

@implementation AWContentFilterHandler

+ (AWContentFilterHandler *)sharedInstance
{
    static dispatch_once_t onceToken;
    static AWContentFilterHandler *awContentFilterHandler = nil;
    
    dispatch_once(&onceToken, ^{
        
        awContentFilterHandler = [[AWContentFilterHandler alloc] init];
    });
    
    return awContentFilterHandler;
}


- (void)setupContentFilter:(id<AWContentFilteringPayload>)contentFilterPayload withCompletion:(contentFilterSetupCompletion)callback
{
    if (_isSettingUpProxy)
    {
        return;
    }
    if (!contentFilterPayload)
    {
        AWLogInfo(@"Payload empty");
        NSError *error = [NSError errorWithDomain:AWSDKErrorDomain code:AWContentFilterSetupErrorPayloadEmpty userInfo:nil];
        if (callback)
            callback(NO,error);
        return;
    }
    self.completionBlock = callback;
    _isSettingUpProxy = YES;

    
    if(contentFilterPayload.contentFilterType == AWContentFilterServerTypeWebSense)
    {
        AWContentFilter *contentFilter = [AWContentFilter sharedInstance];
        NSInteger websenseAccountId = [contentFilterPayload websenseAccountId];
        NSString *websensePacAddress = [contentFilterPayload websensePacAddress];
        NSString *websenseSecurityKey = [contentFilterPayload websenseSecurityKey];
        
        if ([contentFilter websenseAccountId] == websenseAccountId &&
            [[contentFilter websensePacAddress] isEqualToString:websensePacAddress] &&
            [[contentFilter websenseSecurityKey] isEqualToString:websenseSecurityKey])
        {
            //Same payload information
            [self returnWithSuccess:YES andError:nil];
            return;
        }
        
        if (websenseAccountId <= 0) {
            NSError *returnError = [NSError errorWithDomain:AWSDKErrorDomain code:AWContentFilterSetupErrorWebsenseAccountIDEmpty userInfo:nil];
            [self returnWithSuccess:NO andError:returnError];
            return;
        }
        
        if ([websensePacAddress length] <= 0)
        {
            NSError *returnError = [NSError errorWithDomain:AWSDKErrorDomain code:AWContentFilterSetupErrorWebsensePacAddressEmpty userInfo:nil];
            [self returnWithSuccess:NO andError:returnError];
            return;
        }
        
        if ([websenseSecurityKey length] <= 0)
        {
            NSError *returnError = [NSError errorWithDomain:AWSDKErrorDomain code:AWContentFilterSetupErrorWebsenseSecurityKeyEmpty userInfo:nil];
            [self returnWithSuccess:NO andError:returnError];
            return;
        }
        [contentFilter setDelegate:self];
        [contentFilter configureWebsenseWithPac:websensePacAddress securityKey:websenseSecurityKey accountId:websenseAccountId];
        [contentFilter start:nil];
        
        [self returnWithSuccess:YES andError:nil];
    }
}

- (void)returnWithSuccess:(BOOL)success andError:(NSError *)error
{
    _isSettingUpProxy = NO;
    if (self.completionBlock)
        self.completionBlock(success,error);
}



#pragma mark AWContentFilterDelegate

- (BOOL)shouldFilterContentForRequest:(NSURLRequest *)request
{
    if (!request) {
        /* Safeguard incase request is nil */
        return NO;
    }
    
    NSDictionary *proxyInfo = [[AWContentFilter sharedInstance] getProxySettingsForURL:[request URL]];
    NSString *host = [proxyInfo objectForKey:(NSString *)kCFProxyHostNameKey];
    
    if(!host || (host && [host length] <= 0)) {
        return NO;
    }
    
    return YES;
}


@end
