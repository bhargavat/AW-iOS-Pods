#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AWCorePlatformHelpers.h"
#import "AWMethodSwizzle.h"
#import "AWSecurityWrapper.h"
#import "UIDevice+Console.h"
#import "UIDevice+Networking.h"

FOUNDATION_EXPORT double AWHelpersVersionNumber;
FOUNDATION_EXPORT const unsigned char AWHelpersVersionString[];

