//
//  VHProxyForwarder.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AWRequestSigner.h"

@protocol VHDispatchRunLoopQueuing;

@interface VHProxyForwarder : NSObject <NSStreamDelegate>
- (VHProxyForwarder *)initWithInput:(NSInputStream *)input
                             output:(NSOutputStream *)output
                              label:(NSString *)label
                              queue:(id<VHDispatchRunLoopQueuing>)queue
                               signatureType:(AWRequestSignerType)sign;
- (void)startWithCompletion:(dispatch_block_t)completion;
- (void)cancel;
@end
