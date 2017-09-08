//
//  VHWebKitErrors.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kVHWebKitErrorDomain;

/**
 * \brief WebKit error codes
 */
typedef enum VHWebKitErrorCode : NSInteger {
   VH_WEBKIT_CANNOT_SHOW_MIME_TYPE = 100,
   VH_WEBKIT_CANNOT_SHOW_URL = 101,
   VH_WEBKIT_FRAME_LOAD_INTERRUPTED = 102,
} VHWebKitErrorCode;
