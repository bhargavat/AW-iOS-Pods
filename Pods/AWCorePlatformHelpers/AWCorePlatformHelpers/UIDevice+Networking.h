//
//  UIDevice+Networking.h
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import <UIKit/UIKit.h>


@interface AWNetworkAdapter : NSObject

@property (nonatomic, assign) sa_family_t family;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* ipV4Address;
@property (nonatomic, copy) NSString* ipV6Address;
@property (nonatomic, copy) NSString* MACAddress;
@property (nonatomic, assign) UInt32 sentBytes;
@property (nonatomic, assign) UInt32 receivedBytes;
@property (nonatomic, assign) UInt32 sentPackets;
@property (nonatomic, assign) UInt32 receivedPackets;
@property (nonatomic, assign) BOOL isLoopback;

-(NSDictionary*)getInfo;

@end

@interface UIDevice (Networking)

- (NSArray *)AW_networkAdapters;

@end