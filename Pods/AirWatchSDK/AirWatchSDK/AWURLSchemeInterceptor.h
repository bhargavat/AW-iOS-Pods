//
//  AWURLSchemeInterceptor.h
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <Foundation/Foundation.h>

@interface AWURLSchemeInterceptor : NSObject

@property (nonatomic) BOOL dataLossPreventionEnabled;
@property (nonatomic) BOOL redirectComposeEmailEnabled;
@property (nonatomic) BOOL redirectWebURLEnabled;


+(AWURLSchemeInterceptor *)sharedInstance;

-(void)updateInterceptingActivity;

/*
 @description: This method checks and returns if the specified scheme is activated to intercept for manipulation.
 @return: activated or deactivated status.
 **/
-(BOOL)isSchemeActivated:(NSString*)scheme;

-(BOOL)isActive;

/*
 @description: This method returns the specified target scheme to use instead of the corresponding system's custom URL schemes. When app's opt in, the http, https and mailto URL schemes are replaced to awb, awbs and awemailclient respectively. This will cause the apps to open such links into the corresponding AW app. The default target schemes can be overriden to any other app's scheme in the plist file.
 @param: A custom URL scheme. For now, only http, https and mailto is supported.
 @return: Target scheme to use for the specified scheme.
 
 **/
-(NSString *) awURLSchemeForScheme:(NSString *)scheme;

/*
 @description: This method returns a user friendly name for a custom URL scheme. For example, "open link" is the scheme name for "http" and "https".
 @return: User friendly scheme name.
 **/
-(NSString *) schemeName:(NSString *)scheme;
@end
