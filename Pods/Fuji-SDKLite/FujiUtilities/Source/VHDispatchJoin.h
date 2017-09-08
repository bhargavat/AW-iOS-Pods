//
//  VHDispatchJoin.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol VHDispatchSerialQueuing;

@interface VHDispatchJoin : NSObject
- (VHDispatchJoin *)initWithQueue:(id<VHDispatchSerialQueuing>)queue;
- (void)start;
- (void)finish;
- (void)join:(dispatch_block_t)completion;
@end
