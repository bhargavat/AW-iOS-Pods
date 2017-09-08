//
//  VHProxyService.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VHProxyServerSocketDelegate.h"

@protocol VHDispatchRunLoopQueuing;

typedef void(^VHProxyServiceStartCompletion)(NSString *localHost, NSInteger localPort, NSError *error);

@interface VHProxyService : NSObject <VHProxyServerSocketDelegate>
- (VHProxyService *)initWithQueue:(id<VHDispatchRunLoopQueuing>)queue;
- (void)startWithProxyHost:(NSString *)host
                 proxyPort:(NSInteger)port
  authenticateCertificates:(BOOL)authenticateCertificates
                 onStarted:(VHProxyServiceStartCompletion)onStarted;
- (void)stopWithCompletion:(dispatch_block_t)completion;
- (void)willEnterForeground;

-(BOOL)isServiceEnabled;

@end
