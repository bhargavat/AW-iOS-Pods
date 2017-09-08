//
//  VHProxyConnectionList.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VHDispatchRunLoopQueuing;
@class VHProxyConnectionList;
@class AWProxyConnection;

@interface VHProxyConnectionList : NSObject
- (VHProxyConnectionList *)initWithQueue:(id<VHDispatchRunLoopQueuing>)queue;
- (void)add:(AWProxyConnection *)connection;
- (void)remove:(AWProxyConnection *)connection;
- (void)close;
@end
