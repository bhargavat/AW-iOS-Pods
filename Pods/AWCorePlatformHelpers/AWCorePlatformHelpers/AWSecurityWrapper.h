//
//  AWSecurityWrapper.h
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <netinet/in.h>

@interface AWSecurityWrapper : NSObject

/// Helper method, as Swift cannot handle #ifdef-s
+ (BOOL)isSimulator;

/// SecController wrapper
+ (SecAccessControlRef)secObjectForUnlockedThisDeviceOnly;

/**
 * Retrieve the system local network identifier
 *
 * @return the inet id for the system in network byte order
 */
+ (uint)localNetNumber;

@end