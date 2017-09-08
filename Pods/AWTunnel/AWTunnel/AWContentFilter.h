//
//  AWContentFilter.h
//  AirWatch
//
//  Created by Vishal Patel on 11/18/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

#import <Foundation/Foundation.h>

@protocol AWContentFilterDelegate <NSObject>

@optional
- (BOOL)shouldFilterContentForRequest:(NSURLRequest *)request;

@end

@interface AWContentFilter : NSObject

+ (AWContentFilter*)sharedInstance;

@property (nonatomic, unsafe_unretained) id<AWContentFilterDelegate> delegate;

@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign, readonly)BOOL isEnabled;
@property (nonatomic, copy) NSString *websensePacAddress;
@property (nonatomic, copy) NSString *websenseSecurityKey;
@property (nonatomic, assign) NSInteger websenseAccountId;
#if 0
@property (nonatomic, strong) NSMutableDictionary *categoryToURLMap;

/* websense threat seeker*/
- (BOOL)isAllowedCategoryFilter:(NSString*)urlString;

#endif

- (BOOL)start:(NSError**)error;
- (void)stop;
- (NSDictionary *)getProxySettingsForURL:(NSURL *)url;

- (void)configureWebsenseWithPac: (NSString *) pacAddress securityKey:(NSString *) secKey accountId: (NSInteger) accountId;

@end
