//
//  AWLocalization.h
//  AWLocalization
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import <UIKit/UIKit.h>

//! Project version number for AWLocalization.
FOUNDATION_EXPORT double AWLocalizationVersionNumber;

//! Project version string for AWLocalization.
FOUNDATION_EXPORT const unsigned char AWLocalizationVersionString[];


//! C macros to be used in Objective C code path
#define AWSDKLocalizedString(_key, _comment) \
        [AWSDKLocalization getLocalizationString:(_key) \
                                                :(_comment)]


