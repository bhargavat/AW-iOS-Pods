//
//  AWProxyForwarder.h
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
#import "AWRequestSigner.h"
#import "AWProxyConnection.h"

@protocol VHDispatchRunLoopQueuing;

@interface AWProxyForwarder : NSObject <NSStreamDelegate>

- (AWProxyForwarder *)initWithInput:(NSInputStream *)input
                             output:(NSOutputStream *)output
                              label:(NSString *)label
                              queue:(id<VHDispatchRunLoopQueuing>)queue
                      signatureType:(AWRequestSignerType)signatureType
                    isRequestDirect:(BOOL) isRequestDirect
                     isRequestHTTPS:(BOOL) isRequestHTTPS
                        requestHost:(NSString *) requestHost;
- (void)startWithCompletion:(dispatch_block_t)completion;
- (void)cancel;

@end