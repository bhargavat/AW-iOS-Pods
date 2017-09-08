//
//  AWCorePlatformHelpers.h
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <UIKit/UIKit.h>

//! Project version number for AWCorePlatformHelpers.
FOUNDATION_EXPORT double AWCorePlatformHelpersVersionNumber;

//! Project version string for AWCorePlatformHelpers.
FOUNDATION_EXPORT const unsigned char AWCorePlatformHelpersVersionString[];

// In this header, you should import all the public headers of your framework
// using statements like #import <AWCorePlatformHelpers/PublicHeader.h>

extern NSString *const AWReachabilityDidChangeNotification;

#import "UIDevice+Console.h"
#import "UIDevice+Networking.h"
#import "AWSecurityWrapper.h"
#import "AWMethodSwizzle.h"
