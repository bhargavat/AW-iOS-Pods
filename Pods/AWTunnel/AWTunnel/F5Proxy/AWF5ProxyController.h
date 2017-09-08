//  AWF5ProxyController.h
//  Airwatch
//
//  Created by Sijo Paulose on 7/23/13.
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
//

#if INCLUDE_F5 && !TARGET_IPHONE_SIMULATOR
#import <Foundation/Foundation.h>

@interface AWF5ProxyController : NSObject

@property(nonatomic, assign, readonly)BOOL isEnabled;

+ (AWF5ProxyController *)sharedInstance;

- (BOOL)startF5ProxyWithError:(NSError**)error;
- (void)stopF5proxy;

- (int)socketHandleForRequest:(NSURLRequest *)request
                    withError:(NSError**)error;

@end
#endif