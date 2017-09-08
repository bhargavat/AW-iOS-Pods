//
//  AWProxyHandler.h
//  AirWatch
//
//  Created by AirWatch on 12/17/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import <Foundation/Foundation.h>

extern NSString *const magReachabilityTestURL;

typedef enum
{
	AWProxySetupErrorPayloadEmpty=23000,
	AWProxySetupErrorTypeNotSupported,
	AWProxySetupErrorHostNameEmpty,
	AWProxySetupErrorNotConfigured

}AWProxySetupError;

typedef void (^ProxySetupCompletion)(BOOL success,NSError *error);

@protocol AWProxySetupDelegate <NSObject>

@optional
- (NSData*) certificateData;
- (NSString*) certificatePassword;
- (NSUInteger) deviceInfoLevelForRSAAA;

@end

@protocol AWProxyDelegate;
@protocol AWProxyPayload;

@interface AWProxyHandler : NSObject

@property (nonatomic, unsafe_unretained) id< AWProxySetupDelegate, AWProxyDelegate> delegate;

+ (AWProxyHandler*)sharedInstance;

+ (BOOL)domain:(NSString *)domain matchesRequest:(NSURLRequest *)request;

+ (BOOL)URLRegex:(NSString *)urlRegex matchesRequestString:(NSString *)requestString;

- (void)setupProxy:(id)proxyPayload withCompletion:(ProxySetupCompletion)callback;
@end
