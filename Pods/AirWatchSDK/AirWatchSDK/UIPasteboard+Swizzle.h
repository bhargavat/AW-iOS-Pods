//
//  UIPasteboard+Swizzle.h
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <UIKit/UIKit.h>

@interface UIPasteboard (Swizzle)

/**
 @description: This method always returns general pasteboard instance. Applications should use this method to get general UIPasteboard instance as it might have been swizzled to return a different instance.
 @params: void
 @return: general UIPasteboard instance.
*/
+(UIPasteboard *) awgeneralPasteboard;

/**
 @description: This method always returns private pasteboard instance. Applications should use this method to get private UIPasteboard instance where all the private pasteboard data is stored. The data stored in this pasteboard is being shared by all apps with same Team ID.
 @params: void
 @return: private UIPasteboard instance.
 */
+(UIPasteboard *) awprivatePasteboard;

/**
 @description: This method removes data from the pasteboard for the specified type.
 @params: pasteboard type
 @return: void
 */
-(void) removeItemForPasteboardType:(CFStringRef) itemType;

@end
