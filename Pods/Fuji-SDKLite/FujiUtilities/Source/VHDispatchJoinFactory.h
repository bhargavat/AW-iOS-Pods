//
//  VHDispatchJoinFactory.h
//  utilities
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VHDispatchSerialQueuing;

@class VHDispatchJoin;

@interface VHDispatchJoinFactory : NSObject

- (id)initWithQueue:(id<VHDispatchSerialQueuing>)queue;
- (VHDispatchJoin *)createDispatchJoin;

@end
