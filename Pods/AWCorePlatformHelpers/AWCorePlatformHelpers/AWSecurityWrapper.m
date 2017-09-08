//
//  AWSecurityWrapper.m
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import "AWSecurityWrapper.h"

@implementation AWSecurityWrapper

+ (BOOL)isSimulator {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#else
    return NO;
#endif
}

+ (SecAccessControlRef)secObjectForUnlockedThisDeviceOnly
{
    CFErrorRef keychainError = NULL;

    SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                    kSecAccessControlUserPresence,
                                                                    &keychainError);
    if (sacObject == NULL || keychainError != NULL) {
        NSString * errorString = [NSString stringWithFormat:@"Cannot create sacObject <%@>",
                                  keychainError];
        // TODO: Get CocoaLumberjack working for Objective-C
        NSLog(@"<%s>(%s)[%d] - %@",
              __FILE__, __FUNCTION__, __LINE__, errorString);
        return NULL;
    }

    return sacObject;
}

+ (uint)localNetNumber
{
    // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0.

     return htonl(IN_LINKLOCALNETNUM);
}
@end
