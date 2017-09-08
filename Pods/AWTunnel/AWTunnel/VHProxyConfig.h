//
//  VHProxyConfig.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class vmPolicies;

@interface VHProxyConfig : NSObject
@property (nonatomic, retain) NSString *proxyHost;
@property (nonatomic) NSInteger proxyPort;
@property (nonatomic) BOOL authenticateCertificates;
@property (nonatomic) BOOL scoped;
@property (nonatomic) BOOL ftpPassive;
@property (nonatomic, retain) NSArray *exceptionsList;

@property (nonatomic, retain) NSMutableArray *whiteList;
@property (nonatomic, retain) NSArray *localURLs;

- (VHProxyConfig *)initWithPolicies:(void *)policies;
- (BOOL)configureLocalHost:(NSString *)localHost
                 localPort:(NSInteger)localPort;
@end
