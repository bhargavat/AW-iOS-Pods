//
//  AWForwarderService.h
//  AirWatch
//
//  Created by Vishal Patel on 11/19/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */

#import <Foundation/Foundation.h>

extern NSString *const kAWForwarderServiceProxyStarted;

typedef enum
{
    AWForwardDomainTypeProxy = 0,
    AWForwardDomainTypeContentFilter
}AWForwardDomainType;


@interface AWForwarderService : NSObject

@property (nonatomic, assign) NSInteger localProxyPort;

+ (AWForwarderService *) sharedInstance;


-(BOOL) startForwarderService;
-(void) stopForwarderServiceWithCompletion: (dispatch_block_t) completion;
-(void) stopProxyWithCompletion: (dispatch_block_t) completion;
-(void) stopContentFilterWithCompletion: (dispatch_block_t) completion;
@end