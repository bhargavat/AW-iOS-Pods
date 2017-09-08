//
//  NSNotificationCenter+Utils.h
//  utilities
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNotificationCenter (Utils)

- (void)postNotificationOnMainThread:(NSNotification *)notification;

- (void)postNotificationNameOnMainThread:(NSString *)name object:(id)object;

- (void)postNotificationNameOnMainThread:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo;

@end
