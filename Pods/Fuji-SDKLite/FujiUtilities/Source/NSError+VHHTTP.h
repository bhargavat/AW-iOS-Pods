//
//  NSError+VHHTTP.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VHHTTPStatus.h"

@interface NSError (VHHTTP)
- (BOOL)isVHHTTPErrorWithStatusCode:(VHHTTPStatusCode)statusCode;
- (BOOL)isVHHTTPError;
@end
