//
//  AWProxyConnection.h
//  AirWatch
//
//  Created by Vishal Patel on 7/11/14.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#import <Foundation/Foundation.h>

@protocol VHDispatchRunLoopQueuing;

@interface AWProxyConnection : NSObject <NSStreamDelegate>

- (void)startWithQueue:(id<VHDispatchRunLoopQueuing>)queue
              localSocket:(CFSocketNativeHandle)localSocket
                     host:(NSString *)host
                     port:(NSInteger)port
 authenticateCertificates:(BOOL)authenticateCertificates
               completion:(dispatch_block_t)completion;
- (void)close;


@end