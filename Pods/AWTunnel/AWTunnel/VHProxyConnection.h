//
//  VHProxyConnection.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VHDispatchRunLoopQueuing;

@interface VHProxyConnection : NSObject
-    (void)startWithQueue:(id<VHDispatchRunLoopQueuing>)queue
              localSocket:(CFSocketNativeHandle)localSocket
                     host:(NSString *)host
                     port:(NSInteger)port
 authenticateCertificates:(BOOL)authenticateCertificates
               completion:(dispatch_block_t)completion;
- (void)close;
@end
