//
//  VHNetworkActivityManager.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol VHDispatchSerialQueuing;

@interface VHNetworkActivityManager : NSObject
- (id)initInContext:(UIApplication *)myContext
          withQueue:(id<VHDispatchSerialQueuing>)queue;
- (void)start;
- (void)startImmediately;
- (void)stop;
@end
